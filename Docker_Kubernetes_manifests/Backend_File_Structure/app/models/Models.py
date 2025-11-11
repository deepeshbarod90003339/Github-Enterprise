import re
from fastapi.exceptions import RequestValidationError,HTTPException
from pydantic import BaseModel, Field
from typing import Any, Optional,Literal
    

class ProjectDetails(BaseModel):
    apms_id: str = Field(..., description="APMS ID of the project")
    ci_id: str = Field(..., description="Configuration item ID")
    business_unit: str
    data_classification: str
    environment: str
    data_sharing_type: str
    transfer_type: str


class SourceDetails(BaseModel):
    bucket: str
    path: str
    file_format: str
    kms_arn: str
    region: str
    vendor_name: Optional[str] = None


class TargetDetails(BaseModel):
    bucket: str
    path: str
    kms_arn: str
    region: str
    vendor_name: Optional[str] = None


class PipelineDetails(BaseModel):
    frequency: str
    schedule_type: Optional[str] = None
    cron_expression: Optional[str] = None
    planned_end_date: Optional[str] = None 
    every_hours: Optional[int] = None
    at_minutes: Optional[int] = None
    day_of_week: Optional[str] = None
    day_of_month: Optional[int] = None
    time: Optional[str] = None 


class CrossAccount(BaseModel):
    source_details: SourceDetails
    target_details: TargetDetails
    pipeline: PipelineDetails
    acknowledgement: bool

class CrossAccountPayload(BaseModel):
    project_details: ProjectDetails
    cross_account: CrossAccount
