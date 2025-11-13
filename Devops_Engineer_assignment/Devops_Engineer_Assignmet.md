# DevOps Engineer - Technical Assignment

**Time Allocation:** ~8 hours  
**Submission Deadline:** 7 days from receipt  
**Submission Format:** GitHub repository (public or private with access granted)

---

## Scenario Overview

You've joined a product company that builds a SaaS compliance automation platform. The platform consists of multiple microservices that collect data from various sources, process it, and generate reports for clients.

Your first project is to set up the infrastructure and deployment pipeline for a new **Data Collection Service** that needs to be deployed to multiple client environments (on-premises infrastructure).

---

## Assignment Tasks

### Part 1: Infrastructure Design & Architecture (Estimated Time: 1.5 hours)

#### Task 1.1: System Architecture Document
Create a detailed architecture document (Markdown format) that describes how you would design the deployment infrastructure for this service. Your document should address:

1. **Deployment Architecture**
   - How would you structure the deployment for multiple client environments?
   - Each client environment may have different scaling requirements
   - The service needs to scale based on workload
   - Consider security and isolation between clients

2. **Container Strategy**
   - Explain your approach to containerizing the service
   - How would you handle configuration management across different client environments?
   - What's your strategy for secrets management (API keys, credentials)?

3. **Failure Scenarios & Recovery**
   - Identify at least 5 potential failure scenarios in a production deployment
   - For each scenario, describe:
     - How you would detect it
     - How you would mitigate/recover from it
     - How you would prevent it from recurring

4. **Monitoring Strategy**
   - What metrics would you collect? (Be specific)
   - How would you implement health checks?
   - What alerts would you configure?

**Deliverable:** `docs/ARCHITECTURE.md`

---

### Part 2: Docker Implementation (Estimated Time: 2 hours)

#### Task 2.1: Multi-stage Dockerfile
Create a production-ready Dockerfile for a Python FastAPI application with the following requirements:

**Application Details:**
- Python 3.11+ application
- Uses FastAPI framework
- Requires: fastapi, uvicorn, pydantic, requests, sqlalchemy
- Application runs on port 8000
- Should run as non-root user
- Includes a health check endpoint at `/health`

**Requirements:**
- Use multi-stage build to minimize final image size
- Implement proper security practices (non-root user, minimal attack surface)
- Add appropriate labels for versioning and metadata
- Include health checks
- Optimize layer caching for faster builds

#### Task 2.2: Docker Compose Configuration
Create a `docker-compose.yml` file that includes:

1. **Data Collection Service** (from your Dockerfile)
2. **PostgreSQL Database** (for storing collected data)
3. **Redis Cache** (for job queuing)
4. **Nginx** (as reverse proxy)

Requirements:
- Proper network isolation between services
- Volume management for persistent data
- Environment variable configuration
- Resource limits (CPU, memory)
- Restart policies
- Logging configuration

#### Task 2.3: Security Hardening
Create a document explaining:
- Security vulnerabilities in a typical Docker deployment
- Your mitigation strategies in your implementation
- How you would scan and maintain container security

**Deliverables:**
- `Dockerfile`
- `docker-compose.yml`
- `docs/DOCKER_SECURITY.md`

---

### Part 3: CI/CD Pipeline (Estimated Time: 2 hours)

#### Task 3.1: GitHub Actions Workflow
Create a complete GitHub Actions workflow (`.github/workflows/deploy.yml`) that:

1. **Triggers on:**
   - Push to main branch
   - Pull requests
   - Manual workflow dispatch with environment selection

2. **Build Stage:**
   - Runs linting (pylint/flake8)
   - Runs unit tests with coverage reporting
   - Builds Docker image
   - Scans image for vulnerabilities
   - Tags image appropriately (include versioning strategy)

3. **Deploy Stage (Staging):**
   - Deploys to staging environment on successful build
   - Runs smoke tests
   - Requires manual approval for production deployment

4. **Deploy Stage (Production):**
   - Implements blue-green or canary deployment strategy
   - Includes rollback mechanism
   - Sends deployment notification

#### Task 3.2: Deployment Strategy
Create a detailed document explaining:
- Your versioning and tagging strategy
- How you handle database migrations during deployment
- Your rollback process
- How you would implement this for 20+ client environments

**Deliverables:**
- `.github/workflows/deploy.yml`
- `docs/DEPLOYMENT_STRATEGY.md`

---

### Part 4: Automation & Scripting (Estimated Time: 1.5 hours)

#### Task 4.1: UNIX Shell Script - Environment Setup
Create a bash script (`scripts/setup-environment.sh`) that:

1. **Pre-flight Checks:**
   - Verifies all required tools are installed (Docker, Docker Compose, Python, etc.)
   - Checks system resources (disk space, memory)
   - Validates network connectivity to required endpoints

2. **Environment Configuration:**
   - Creates necessary directory structure
   - Generates configuration files from templates
   - Sets up logging directories with proper permissions

3. **Deployment:**
   - Pulls latest images or builds from source
   - Starts services in correct order
   - Waits for services to be healthy before proceeding
   - Runs initial database migrations

4. **Validation:**
   - Performs health checks on all services
   - Generates a status report
   - Outputs success/failure with detailed logs

**Requirements:**
- Proper error handling and logging
- Idempotent (can be run multiple times safely)
- Colored output for better readability
- Exit codes that indicate success/failure states

#### Task 4.2: Python FastAPI Script - Automation Endpoint
Create a simple FastAPI application (`app/main.py`) with the following endpoints:

1. **`GET /health`** - Health check endpoint
2. **`POST /api/v1/jobs/trigger`** - Triggers a data collection job
   - Accepts: `{"source_type": "api|database|file", "config": {...}}`
   - Returns: Job ID and status
3. **`GET /api/v1/jobs/status/{job_id}`** - Get job status
4. **`GET /api/v1/jobs/result/{job_id}`** - Get job result

Requirements:
- Proper request validation using Pydantic models
- Error handling and appropriate HTTP status codes
- Async operations where appropriate
- OpenAPI documentation (auto-generated by FastAPI)
- Structured logging

**Deliverables:**
- `scripts/setup-environment.sh`
- `app/main.py`
- `app/requirements.txt`
- `README.md` with usage instructions

---

### Part 5: Problem-Solving & Troubleshooting (Estimated Time: 1 hour)

#### Scenario-Based Questions
Answer the following scenarios in `docs/TROUBLESHOOTING.md`. For each, provide:
- Your diagnostic approach (step-by-step)
- Tools you would use
- Potential root causes
- Resolution steps
- Prevention strategies

**Scenario 1: Deployment Failure**
```
Your GitHub Actions pipeline is failing at the deployment stage with this error:
"Error response from daemon: manifest for myapp:v1.2.3 not found"

The build stage completed successfully. What could be wrong?
Provide at least 3 possible causes and how you'd investigate each.
```

**Scenario 2: Performance Degradation**
```
After deployment, the service is taking 10x longer to process requests than before.
- Previous: 100 records processed in 5 minutes
- Current: 100 records processed in 50 minutes

The service logs show no errors. System resources (CPU, memory) are at 30% utilization.
How would you diagnose this issue?
```

**Scenario 3: Container Networking Issue**
```
Your Docker Compose stack is running, but the application service 
can't communicate with the PostgreSQL database. 

Logs show: "psycopg2.OperationalError: could not connect to server: 
Connection refused"

The database container is running and healthy. What would you check?
```

**Scenario 4: On-Premises Deployment Challenge**
```
You need to deploy your containerized service to a client's on-premises environment.
They have:
- Traditional virtualization infrastructure (VMware, Hyper-V, or similar)
- Strict network segmentation (DMZ, internal network, management network)
- No internet access from production servers
- Air-gapped environment for sensitive data

How would you approach this deployment? What challenges do you foresee 
and how would you address them?
```

**Scenario 5: CI/CD Pipeline Optimization**
```
Your current GitHub Actions workflow takes 25 minutes to complete.
Breakdown:
- Dependencies installation: 8 minutes
- Linting: 2 minutes
- Testing: 5 minutes
- Docker build: 10 minutes

The team deploys 10-15 times per day. How would you optimize this pipeline?
Provide specific strategies and expected time savings.
```

**Deliverable:** `docs/TROUBLESHOOTING.md`

---

## Evaluation Criteria

Your submission will be evaluated on:

### Technical Competency (40%)
- Correct implementation of Docker, CI/CD, and automation scripts
- Code quality and best practices
- Security considerations
- Understanding of the technology stack

### Problem-Solving & Logical Thinking (30%)
- Quality of architectural decisions
- Depth of troubleshooting analysis
- Creativity in solving constraints
- Understanding of failure modes and recovery

### Documentation & Communication (20%)
- Clarity of documentation
- Completeness of explanations
- README quality
- Code comments where necessary

### AI-Assisted Development (10%)
- Include a section in your README describing:
  - Which AI tools you used (if any)
  - How they helped in your workflow
  - What you learned or refined through AI assistance
  - Any challenges you faced with AI-generated code

---

## Submission Requirements

1. **GitHub Repository Structure:**
   ```
   ├── .github/
   │   └── workflows/
   │       └── deploy.yml
   ├── app/
   │   ├── main.py
   │   └── requirements.txt
   ├── scripts/
   │   └── setup-environment.sh
   ├── docs/
   │   ├── ARCHITECTURE.md
   │   ├── DOCKER_SECURITY.md
   │   ├── DEPLOYMENT_STRATEGY.md
   │   └── TROUBLESHOOTING.md
   ├── Dockerfile
   ├── docker-compose.yml
   └── README.md
   ```

2. **README.md must include:**
   - Setup instructions
   - How to run/test each component
   - Assumptions you made
   - Any dependencies or prerequisites
   - Time spent on each section
   - AI tools used and how

3. **Code Quality:**
   - All scripts should be executable and tested
   - Include comments for complex logic
   - Follow language-specific conventions
   - No hardcoded credentials (use environment variables)

4. **Optional Bonus (Not required but valued):**
   - Working demo environment (using Docker Compose)
   - Automated tests for the FastAPI application
   - Infrastructure as Code example (Terraform or Ansible)
   - Cost optimization analysis

---

## Submission Instructions

1. Create a GitHub repository (public or private)
2. Include a brief cover note highlighting any specific areas you're proud of or challenges you faced

---

## Important Notes

- **Don't over-engineer:** We're looking for practical, production-ready solutions, not academic exercises
- **Ask questions:** If you need clarification, email us. Good engineers ask good questions
- **Manage your time:** You don't need to achieve perfection in all areas. Demonstrate breadth and depth strategically
- **Be honest:** If you use AI assistance or reference documentation, that's expected and encouraged. Just document it
- **Real-world focus:** Consider this as if you were actually deploying to production

---


**Good luck! We're excited to see your approach to solving these challenges.**
