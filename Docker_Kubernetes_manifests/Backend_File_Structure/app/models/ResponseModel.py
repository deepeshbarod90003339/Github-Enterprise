from pydantic import BaseModel
from typing import Any, Optional,Literal

class SuccessResponse(BaseModel):
    status: str
    message: str
    data: Optional[Any] = None
    
class ErrorResponse(BaseModel):
    status: str
    message: str
    data: Optional[Any] = None