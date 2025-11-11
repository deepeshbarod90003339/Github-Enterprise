from fastapi import FastAPI, APIRouter, Request,HTTPException
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from app.routers import common_router
from app.utils.LogUtils import logger
from starlette.middleware.cors import CORSMiddleware
from app.middleware.AuthMiddleware import okta_auth_middleware
from contextlib import asynccontextmanager
from app.utils.VaultClient import vault_client

@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        #  Startup phase
        logger.info("Starting DSaaS Backend API...")

        # Initialize Vault client (warm authentication)
        await vault_client._authenticate()
        logger.info("Vault client initialized and authenticated")

        yield  # Run the API normally

    finally:
        #  Shutdown phase
        logger.info("Shutting down DSaaS Backend API...")
        await vault_client.close()
        logger.warning("Vault client closed successfully")
        

API_VERSION = "/services/dataplatform/dsaas"
app = FastAPI(
    title="DSaaS Backend API", 
    openapi_url=f"{API_VERSION}/openapi.json",
    docs_url=f"{API_VERSION}/docs",
    redoc_url=f"{API_VERSION}/redoc",
    lifespan=lifespan
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173","http://10.1.2.205:5173","https://1data-dev.onetakeda.com","https://onedata.onetakeda.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.middleware("http")(okta_auth_middleware)

@app.exception_handler(RequestValidationError)
def validation_exception_handler(request:Request, exc:RequestValidationError):
    logger.error(f"Validation error: {exc.errors()}")
    error = exc.errors()[0]
    return JSONResponse(
        status_code=422,
        content={
            "status": "0",
            "message": error['msg']
        }
    )

@app.exception_handler(HTTPException)
def validation_exception_handler(request:Request, exc:RequestValidationError):
    logger.error(f"Validation error: {exc.detail['message']}")
    return JSONResponse(
        status_code=exc.status_code,
        content=exc.detail
    )

router = APIRouter()
@router.get("/", status_code=200)
def dsaas_root():
    logger.info("DSaaS Backend API root endpoint called")
    return JSONResponse(
        status_code=200,
        content={
            "status": "1",
            "message": "DSaaS Backend API",
            "data": {}
        }
    )

@router.get("/health", status_code=200)
def dsaas_health_check():
    return JSONResponse(
        status_code=200,
        content={
            "status": "1",
            "message": "DSaaS Backend is healthy",
            "data": {}
        }
    )

# Root level health endpoint for ALB
@app.get("/health", status_code=200)
def root_health_check():
    return JSONResponse(
        status_code=200,
        content={
            "status": "1",
            "message": "DSaaS Backend is healthy",
            "data": {}
        }
    )

app.include_router(router,prefix=API_VERSION)   
app.include_router(common_router, prefix=API_VERSION)