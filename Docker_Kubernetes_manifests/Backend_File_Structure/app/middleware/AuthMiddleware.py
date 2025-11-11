import sys,os,requests,json,jwt
from fastapi import HTTPException,Request
from fastapi.responses import JSONResponse
from app.utils.LogUtils import logger
from app.utils import CommonUtilsConstants
from jwt.algorithms import RSAAlgorithm
# from utils.CommonUtils


EXCLUDED_PATHS = [
    "/services/dataplatform/dsaas/docs",
    "/services/dataplatform/dsaas/openapi.json",
    "/services/dataplatform/dsaas/",
    "/services/dataplatform/dsaas/health",
    "/health"  # For ALB health checks
]


def get_kid(token):
    """ Extract the 'kid' from the JWT header """
    try:
        header = jwt.get_unverified_header(token)
        return header.get("kid")
    except Exception:
        return None

def get_public_key(kid):
    """ Get the public key from Okta's JWKS """
    try:
        jwks = requests.get(CommonUtilsConstants.OKTA_JWKS_URL).json()
        if "keys" not in jwks:
            raise HTTPException(
                status_code=500,
                detail={"status": "0", "message": "Malformed JWKS response"}
            )
        for key in jwks["keys"]:
            if key["kid"] == kid:
                return RSAAlgorithm.from_jwk(json.dumps(key))
        raise HTTPException(
            status_code=401,
            detail={"status": "0", "message": "Invalid token signature"}
        )
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=500,
            detail={
                    "status":"0",
                    "message":"Internal Server Error"
                }
        )

def verify_jwt(token:str):
    try:
        kid = get_kid(token)
        if not kid :
            raise HTTPException(
                status_code=401,
                detail={
                    "status":"0",
                    "message":"Missing or Invalid Autherisation Token"
                }
            )
        public_key = get_public_key(kid)
        print(public_key)
        OKTA_CLIENT_ID = "0oa1i7c0qzmneJ54r358"
        decoded_token = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=CommonUtilsConstants.OKTA_AUDIENCE,
            issuer=CommonUtilsConstants.OKTA_ISSUER
        )
        # Validate that the token includes the correct client_id
        if "client_id" in decoded_token and decoded_token["client_id"] != OKTA_CLIENT_ID:
            raise HTTPException(
                status_code=401, 
                detail={
                    "status":"0",
                    "message":"Invalid Client Id"
                })
        
        return decoded_token
    
    except HTTPException:
        raise 
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=401,
            detail={"status": "0", "message": "Token expired"}
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=401,
            detail={"status": "0", "message": "Invalid token"}
        )
    except Exception:
        raise HTTPException(
            status_code=500,
            detail={
                    "status":"0",
                    "message":"Internal Server Error"
                }
        )

async def okta_auth_middleware(request:Request, call_next ):
    try:
        print(request.method)
        if request.method == "OPTIONS":
            return await call_next(request)
        if request.url.path in EXCLUDED_PATHS:
            return await call_next(request)
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(
                status_code=401,
                detail={
                    "status":"0",
                    "message":"Missing or Invalid Autherisation Token"
                }
            )
        
        
        user_token = auth_header.split(" ")[1]
        user = verify_jwt(user_token)
        request.state.user = user # Attach user info to request
        return await call_next(request)
        
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
    