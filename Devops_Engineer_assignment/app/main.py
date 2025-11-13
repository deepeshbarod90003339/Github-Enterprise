from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional
import uuid
import asyncio
import logging
from datetime import datetime, timezone
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Data Collection Service",
    description="A service for collecting and processing data from various sources",
    version="1.0.0"
)

# In-memory storage for demo (use Redis/Database in production)
jobs_store: Dict[str, Dict[str, Any]] = {}

class JobRequest(BaseModel):
    source_type: str = Field(..., pattern="^(api|database|file)$")
    config: Dict[str, Any] = Field(default_factory=dict)

class JobResponse(BaseModel):
    job_id: str
    status: str
    created_at: str

class JobStatus(BaseModel):
    job_id: str
    status: str
    progress: Optional[int] = None
    message: Optional[str] = None
    created_at: str
    updated_at: str

class JobResult(BaseModel):
    job_id: str
    status: str
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None

@app.get("/health")
async def health_check():
    """Health check endpoint for load balancers and monitoring"""
    try:
        # Add dependency checks here (database, redis, etc.)
        return JSONResponse(
            status_code=200,
            content={
                "status": "healthy",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "service": "data-collection-service",
                "version": "1.0.0"
            }
        )
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "error": str(e),
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
        )

async def process_job(job_id: str, source_type: str, config: Dict[str, Any]):
    """Background task to process data collection job"""
    try:
        logger.info(f"Starting job {job_id} with source_type: {source_type}")
        
        # Update job status to processing
        jobs_store[job_id]["status"] = "processing"
        jobs_store[job_id]["updated_at"] = datetime.now(timezone.utc).isoformat()
        
        # Simulate processing time based on source type
        processing_times = {"api": 5, "database": 10, "file": 15}
        await asyncio.sleep(processing_times.get(source_type, 5))
        
        # Simulate successful completion
        jobs_store[job_id].update({
            "status": "completed",
            "result": {
                "records_processed": 100,
                "source_type": source_type,
                "config_used": config
            },
            "updated_at": datetime.now(timezone.utc).isoformat()
        })
        
        logger.info(f"Job {job_id} completed successfully")
        
    except Exception as e:
        logger.error(f"Job {job_id} failed: {str(e)}")
        jobs_store[job_id].update({
            "status": "failed",
            "error": str(e),
            "updated_at": datetime.now(timezone.utc).isoformat()
        })

@app.post("/api/v1/jobs/trigger", response_model=JobResponse)
async def trigger_job(job_request: JobRequest, background_tasks: BackgroundTasks):
    """Trigger a new data collection job"""
    try:
        job_id = str(uuid.uuid4())
        created_at = datetime.now(timezone.utc).isoformat()
        
        # Store job information
        jobs_store[job_id] = {
            "job_id": job_id,
            "status": "queued",
            "source_type": job_request.source_type,
            "config": job_request.config,
            "created_at": created_at,
            "updated_at": created_at
        }
        
        # Start background processing
        background_tasks.add_task(
            process_job, 
            job_id, 
            job_request.source_type, 
            job_request.config
        )
        
        logger.info(f"Job {job_id} queued for processing")
        
        return JobResponse(
            job_id=job_id,
            status="queued",
            created_at=created_at
        )
        
    except Exception as e:
        logger.error(f"Failed to trigger job: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to trigger job: {str(e)}")

@app.get("/api/v1/jobs/status/{job_id}", response_model=JobStatus)
async def get_job_status(job_id: str):
    """Get the status of a specific job"""
    if job_id not in jobs_store:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job = jobs_store[job_id]
    return JobStatus(
        job_id=job["job_id"],
        status=job["status"],
        progress=job.get("progress"),
        message=job.get("message"),
        created_at=job["created_at"],
        updated_at=job["updated_at"]
    )

@app.get("/api/v1/jobs/result/{job_id}", response_model=JobResult)
async def get_job_result(job_id: str):
    """Get the result of a completed job"""
    if job_id not in jobs_store:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job = jobs_store[job_id]
    
    if job["status"] not in ["completed", "failed"]:
        raise HTTPException(
            status_code=400, 
            detail=f"Job is still {job['status']}. Results not available yet."
        )
    
    return JobResult(
        job_id=job["job_id"],
        status=job["status"],
        result=job.get("result"),
        error=job.get("error")
    )

@app.get("/api/v1/jobs")
async def list_jobs():
    """List all jobs with their current status"""
    return {
        "jobs": list(jobs_store.values()),
        "total": len(jobs_store)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)