import yaml
from datetime import datetime, timezone
from fastapi import APIRouter,Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import HTTPException
from app.utils.LogUtils import logger
from app.models import SuccessResponse, ErrorResponse,CrossAccountPayload
from starlette.status import HTTP_200_OK,HTTP_201_CREATED,HTTP_400_BAD_REQUEST,HTTP_401_UNAUTHORIZED,HTTP_403_FORBIDDEN,HTTP_404_NOT_FOUND,HTTP_500_INTERNAL_SERVER_ERROR
from app.utils.CommonUtils import fetch_api,generate_cross_account_payload,get_current_utc_datetime_str,config
from app.utils import CommonUtilsConstants as CUC

common_router = APIRouter(tags=["Common APIs"])

@common_router.post("/create_project", status_code=HTTP_200_OK)
async def create_project(request: Request,payload: CrossAccountPayload):
    try:
        logger.info("Create Project API called")
        # requestor_email_id = "ameya.mahajan@takeda.com"
        requestor_email_id = request.state.user["sub"]
        logger.info(f"Requestor Email ID : {requestor_email_id}")
        current_datetime = get_current_utc_datetime_str()
        pipeline_id = config.get(CUC.CA_PIPELINE_ID)
        logger.info(f"Using Pipeline ID : {pipeline_id}")
        json_input = generate_cross_account_payload(pipeline_id, payload, requestor_email_id,current_datetime)
        response = await fetch_api(pipeline_id, json_input)
        return JSONResponse(
          status_code=201,
          content={
            "status":"1",
            "message" : "Project Created Successfully",
            "data":response
          }
        )
    except HTTPException as ht:
        return JSONResponse(
            status_code=ht.status_code,
            content= ht.detail
        ) 
    except Exception as e:
        logger.info(e)
        return JSONResponse(
            status_code=500,
            content= {"status":"0","message":"An unexpected error occurred. Please try again later."}
        )