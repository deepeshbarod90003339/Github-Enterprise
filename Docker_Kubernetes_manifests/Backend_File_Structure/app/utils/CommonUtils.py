import requests,yaml,json,os,aiohttp,datetime
from app.utils import CommonUtilsConstants
from fastapi.responses import JSONResponse
from fastapi.exceptions import HTTPException
from app.utils.LogUtils import logger
import traceback
from app.utils.VaultClient import vault_client
from app.utils.getconfig import get_config


    
#Config Initialization
config = get_config()


#Function to Fetch Current Environment
def get_current_environment():
    try:
        logger.info("Fetching current environment")
        return config[CommonUtilsConstants.ENVIRONMENT_KEY]
    except Exception as ex:
        raise Exception("ERROR::Unable to fetch current environment", str(ex))


async def fetch_api(pipeline_id: str, payload: dict):
    """
    Asynchronously triggers a Harness pipeline using aiohttp.

    Args:
        pipeline_id (str): The pipeline ID to execute.
        payload (dict | None): The request body payload (if any).

    Returns:
        dict: JSON response from the Harness API if successful.
    """
    try:
        base_url = CommonUtilsConstants.HARNESS_BASE_URL
        api_url = base_url.replace(CommonUtilsConstants.PIPELINE_ID_KEY, pipeline_id)
        curr_env = get_current_environment()
        logger.info("Triggering Harness pipeline for environment: %s", curr_env)
        secret = await vault_client.read_secret(CommonUtilsConstants.HARNESS_KEY_PATH, curr_env)

        headers = {
            "Content-Type": "application/json",
            "x-api-key": secret["x-api-key"],
        }

        async with aiohttp.ClientSession() as session:
            async with session.post(api_url, headers=headers, json=payload) as response:
                response_text = await response.text()

                if response.status == 200:
                    logger.info("Successfully called Harness API")
                    return await response.json()

                logger.error("Failed to call Harness API. Status: %s, Response: %s", response.status, response_text)

                try:
                    error_json = await response.json()
                    error_message = error_json.get("message") or error_json.get("error")
                except Exception:
                    error_message = response_text

                raise HTTPException(
                    status_code=response.status,
                    detail={
                        "status": "0",
                        "message": error_message or "Unknown error occurred while calling Harness API."
                    }
                )

    except HTTPException:
        raise
    except Exception:
        logger.error("Exception occurred while calling Harness API: %s", traceback.format_exc())
        return JSONResponse(
            status_code=500,
            content={
                "status": "0",
                "message": "An unexpected error occurred. Please try again later."
            }
        )

        
        
def get_secret_engine(environment):
    try:
        logger.info("Fetching Vault Secret Engine")
        secret_engine = config[CommonUtilsConstants.VAULT_SECRET_ENGINE].get(environment,"")
        if not secret_engine:
            raise Exception(f"Secret engine not found for environment: {environment}")
        return secret_engine
    except Exception as ex:
        raise Exception("Unable to get secret engine", str(ex))
    
def generate_cross_account_payload(pipeline_id, payload, requestor_email_id,current_datetime_str):
    json_output = {
    "pipeline": {
        "identifier": "TestDJDSaaSCrossAccountDataSharing_Clone",
        "variables": [
            {"name": "apms_id", "type": "String", "value": f"{payload.project_details.apms_id}"},
            {"name": "ci_id", "type": "String", "value": f"{payload.project_details.ci_id}"},
            {"name": "vendor_name", "type": "String", "value": f"{payload.cross_account.source_details.vendor_name if payload.cross_account.source_details.vendor_name else payload.cross_account.target_details.vendor_name}"},
            {"name": "business_unit", "type": "String", "value": f"{payload.project_details.business_unit}"},
            {"name": "system_owner_email_id", "type": "String", "value": f"{requestor_email_id}"},
            {"name": "business_owner_email_id", "type": "String", "value": f"{requestor_email_id}"},
            {"name": "technical_owner_email_id", "type": "String", "value": f"{requestor_email_id}"},
            {"name": "data_classification", "type": "String", "value": f"{payload.project_details.data_classification}"},
            {"name": "source_s3_bucket_name", "type": "String", "value": f"{payload.cross_account.source_details.bucket}"},
            {"name": "source_s3_location", "type": "String", "value": f"{payload.cross_account.source_details.path}"},
            {"name": "source_file_format", "type": "String", "value": f"{payload.cross_account.source_details.file_format}"},
            {"name": "source_kms_arn", "type": "String", "value": f"{payload.cross_account.source_details.kms_arn}"},
            {"name": "target_s3_bucket_name", "type": "String", "value": f"{payload.cross_account.target_details.bucket}"},
            {"name": "target_s3_location", "type": "String", "value": f"{payload.cross_account.target_details.path}"},
            {"name": "target_kms_arn", "type": "String", "value": f"{payload.cross_account.target_details.kms_arn}"},
            {"name": "transfer_type", "type": "String", "value": f"{payload.project_details.transfer_type}"},
            {"name": "pipeline_frequency", "type": "String", "value": f"{payload.cross_account.pipeline.schedule_type if payload.cross_account.pipeline.schedule_type else payload.cross_account.pipeline.frequency}"},
            {"name": "source_aws_region", "type": "String", "value": f"{payload.cross_account.source_details.region}"},
            {"name": "target_aws_region", "type": "String", "value": f"{payload.cross_account.target_details.region}"},
            {"name": "expired_after", "type": "String", "value": f"{payload.cross_account.pipeline.planned_end_date if payload.cross_account.pipeline.planned_end_date else ''}"},
            {"name": "trigger_type", "type": "String", "value": "MANUAL"},
            {"name": "scheduler_type", "type": "String", "value": ""},
            {"name": "scheduler_time", "type": "String", "value": f"{payload.cross_account.pipeline.time if payload.cross_account.pipeline.time else current_datetime_str}"},
            {"name": "is_active", "type": "String", "value": "Y"},
            {"name": "cron_expression", "type": "String", "value": f"{payload.cross_account.pipeline.cron_expression if payload.cross_account.pipeline.cron_expression else ''}"}
            ]
        }
    }
    return json_output

def get_current_utc_datetime_str():
    utc_now = datetime.datetime.now(datetime.timezone.utc)
    return utc_now.strftime("%Y-%m-%dT%H:%M:%S.000")