# 🏗️ Private Subnet Multi-Account Architecture Diagram

## 🎯 **Complete Architecture Overview**

```mermaid
graph TB
    subgraph "AWS Organization"
        subgraph "Dev Account (111111111111)"
            subgraph "VPC 10.1.0.0/16"
                subgraph "Public Subnet 10.1.0.0/24"
                    IGW1[Internet Gateway]
                    NAT1[NAT Gateway]
                end
                
                subgraph "Private Subnets"
                    subgraph "Bastion Subnet 10.1.10.0/24"
                        BASTION1[Bastion Host<br/>Session Manager Access]
                    end
                    
                    subgraph "App Subnet 10.1.1.0/24"
                        EKS1[EKS Cluster<br/>Private Nodes]
                        RDS1[RDS Database<br/>Private]
                    end
                    
                    subgraph "Data Subnet 10.1.2.0/24"
                        EC2_1[EC2 Instances<br/>Private]
                    end
                end
                
                subgraph "VPC Endpoints"
                    SSM1[SSM Endpoint]
                    ECR1[ECR Endpoint]
                    S3_1[S3 Endpoint]
                end
            end
        end
        
        subgraph "Test Account (222222222222)"
            subgraph "VPC 10.2.0.0/16"
                subgraph "Public Subnet 10.2.0.0/24"
                    IGW2[Internet Gateway]
                    NAT2[NAT Gateway]
                end
                
                subgraph "Private Subnets"
                    subgraph "Bastion Subnet 10.2.10.0/24"
                        BASTION2[Bastion Host<br/>Session Manager Access]
                    end
                    
                    subgraph "App Subnet 10.2.1.0/24"
                        EKS2[EKS Cluster<br/>Private Nodes]
                        RDS2[RDS Database<br/>Private]
                    end
                    
                    subgraph "Data Subnet 10.2.2.0/24"
                        EC2_2[EC2 Instances<br/>Private]
                    end
                end
                
                subgraph "VPC Endpoints"
                    SSM2[SSM Endpoint]
                    ECR2[ECR Endpoint]
                    S3_2[S3 Endpoint]
                end
            end
        end
        
        subgraph "Prod Account (333333333333)"
            subgraph "VPC 10.3.0.0/16"
                subgraph "Public Subnet 10.3.0.0/24"
                    IGW3[Internet Gateway]
                    NAT3[NAT Gateway]
                end
                
                subgraph "Private Subnets"
                    subgraph "Bastion Subnet 10.3.10.0/24"
                        BASTION3[Bastion Host<br/>Session Manager Access]
                    end
                    
                    subgraph "App Subnet 10.3.1.0/24"
                        EKS3[EKS Cluster<br/>Private Nodes]
                        RDS3[RDS Database<br/>Private]
                    end
                    
                    subgraph "Data Subnet 10.3.2.0/24"
                        EC2_3[EC2 Instances<br/>Private]
                    end
                end
                
                subgraph "VPC Endpoints"
                    SSM3[SSM Endpoint]
                    ECR3[ECR Endpoint]
                    S3_3[S3 Endpoint]
                end
            end
        end
    end
    
    subgraph "External Access"
        USER[DevOps Engineer]
        INTERNET[Internet]
    end
    
    subgraph "AWS Services"
        SESSION_MGR[AWS Session Manager]
        CLOUDTRAIL[CloudTrail Logging]
        CLOUDWATCH[CloudWatch Logs]
    end
    
    %% Access Flow
    USER -->|AWS CLI + MFA| SESSION_MGR
    SESSION_MGR -->|Encrypted Tunnel| BASTION1
    SESSION_MGR -->|Encrypted Tunnel| BASTION2
    SESSION_MGR -->|Encrypted Tunnel| BASTION3
    
    %% Internal Access
    BASTION1 -->|SSH| EKS1
    BASTION1 -->|SSH| EC2_1
    BASTION2 -->|SSH| EKS2
    BASTION2 -->|SSH| EC2_2
    BASTION3 -->|SSH| EKS3
    BASTION3 -->|SSH| EC2_3
    
    %% Internet Access (Outbound Only)
    NAT1 -->|Outbound Only| INTERNET
    NAT2 -->|Outbound Only| INTERNET
    NAT3 -->|Outbound Only| INTERNET
    
    %% Logging
    BASTION1 -->|Session Logs| CLOUDWATCH
    BASTION2 -->|Session Logs| CLOUDWATCH
    BASTION3 -->|Session Logs| CLOUDWATCH
    
    %% API Logging
    SESSION_MGR -->|API Calls| CLOUDTRAIL
    
    %% Styling
    classDef accountBox fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef privateSubnet fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef publicSubnet fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef bastion fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef endpoint fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    
    class BASTION1,BASTION2,BASTION3 bastion
    class SSM1,SSM2,SSM3,ECR1,ECR2,ECR3,S3_1,S3_2,S3_3 endpoint
```

## 🔐 **Security Flow Diagram**

```mermaid
sequenceDiagram
    participant User as DevOps Engineer
    participant MFA as Multi-Factor Auth
    participant SM as Session Manager
    participant BH as Bastion Host
    participant EKS as EKS Cluster
    participant CW as CloudWatch Logs
    participant CT as CloudTrail
    
    User->>MFA: Authenticate with MFA
    MFA->>SM: Validated Session
    User->>SM: Start Session Request
    SM->>CT: Log API Call
    SM->>BH: Establish Encrypted Tunnel
    BH->>CW: Log Session Start
    
    User->>BH: Execute Commands
    BH->>EKS: SSH to Private Nodes
    BH->>CW: Log All Commands
    
    User->>BH: kubectl commands
    BH->>EKS: Kubernetes API Calls
    EKS->>CW: Log API Server Events
    
    BH->>CW: Log Session End
    SM->>CT: Log Session Termination
```

## 🌐 **Network Flow Diagram**

```mermaid
graph LR
    subgraph "Internet"
        INT[Internet]
    end
    
    subgraph "AWS Account"
        subgraph "Public Subnet"
            IGW[Internet Gateway]
            NAT[NAT Gateway]
        end
        
        subgraph "Private Subnets"
            BASTION[Bastion Host<br/>10.1.10.100]
            EKS[EKS Nodes<br/>10.1.1.0/24]
            RDS[RDS Database<br/>10.1.2.100]
        end
        
        subgraph "VPC Endpoints"
            SSM_EP[SSM Endpoint<br/>com.amazonaws.us-east-1.ssm]
            ECR_EP[ECR Endpoint<br/>com.amazonaws.us-east-1.ecr.dkr]
        end
    end
    
    subgraph "AWS Services"
        SSM[Session Manager]
        ECR[Elastic Container Registry]
    end
    
    %% Outbound Internet Access
    EKS -->|Updates/Packages| NAT
    BASTION -->|Updates/Packages| NAT
    NAT -->|Outbound Only| IGW
    IGW -->|Outbound Only| INT
    
    %% VPC Endpoint Access
    BASTION -.->|Private| SSM_EP
    EKS -.->|Private| ECR_EP
    SSM_EP -.->|Private| SSM
    ECR_EP -.->|Private| ECR
    
    %% Internal Communication
    BASTION -->|SSH 22| EKS
    EKS -->|MySQL 3306| RDS
    
    %% No Inbound Internet Access
    INT -.->|❌ No Inbound| IGW
    
    %% Styling
    classDef noAccess fill:#ffcdd2,stroke:#d32f2f,stroke-width:2px,stroke-dasharray: 5 5
    classDef private fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef public fill:#fff3e0,stroke:#e65100,stroke-width:2px
    
    class INT noAccess
    class BASTION,EKS,RDS,SSM_EP,ECR_EP private
    class IGW,NAT public
```

## 🔧 **Access Pattern Diagram**

```mermaid
graph TD
    subgraph "DevOps Engineer Workstation"
        LAPTOP[Laptop/Desktop<br/>AWS CLI + MFA]
    end
    
    subgraph "AWS Session Manager"
        SM[Session Manager Service<br/>Encrypted Tunnels]
    end
    
    subgraph "Dev Account (111111111111)"
        BASTION_DEV[Bastion Host<br/>i-dev123456789]
        EKS_DEV[EKS Cluster<br/>dev-eks-cluster]
        RDS_DEV[RDS Instance<br/>dev-database]
    end
    
    subgraph "Test Account (222222222222)"
        BASTION_TEST[Bastion Host<br/>i-test123456789]
        EKS_TEST[EKS Cluster<br/>test-eks-cluster]
        RDS_TEST[RDS Instance<br/>test-database]
    end
    
    subgraph "Prod Account (333333333333)"
        BASTION_PROD[Bastion Host<br/>i-prod123456789]
        EKS_PROD[EKS Cluster<br/>prod-eks-cluster]
        RDS_PROD[RDS Instance<br/>prod-database]
    end
    
    %% Access Flow
    LAPTOP -->|aws ssm start-session<br/>--profile dev-account| SM
    LAPTOP -->|aws ssm start-session<br/>--profile test-account| SM
    LAPTOP -->|aws ssm start-session<br/>--profile prod-account| SM
    
    SM -->|Encrypted Tunnel| BASTION_DEV
    SM -->|Encrypted Tunnel| BASTION_TEST
    SM -->|Encrypted Tunnel| BASTION_PROD
    
    BASTION_DEV -->|kubectl/ssh| EKS_DEV
    BASTION_DEV -->|mysql client| RDS_DEV
    
    BASTION_TEST -->|kubectl/ssh| EKS_TEST
    BASTION_TEST -->|mysql client| RDS_TEST
    
    BASTION_PROD -->|kubectl/ssh| EKS_PROD
    BASTION_PROD -->|mysql client| RDS_PROD
    
    %% Styling
    classDef laptop fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef sessionmgr fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef bastion fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef resource fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    
    class LAPTOP laptop
    class SM sessionmgr
    class BASTION_DEV,BASTION_TEST,BASTION_PROD bastion
    class EKS_DEV,EKS_TEST,EKS_PROD,RDS_DEV,RDS_TEST,RDS_PROD resource
```

## 📊 **Monitoring & Logging Flow**

```mermaid
graph TB
    subgraph "Data Sources"
        SM[Session Manager<br/>Connection Logs]
        BH[Bastion Hosts<br/>Command Logs]
        EKS[EKS Clusters<br/>API Server Logs]
        VPC[VPC Flow Logs<br/>Network Traffic]
    end
    
    subgraph "AWS Logging Services"
        CW[CloudWatch Logs<br/>Centralized Logging]
        CT[CloudTrail<br/>API Call Logging]
        CWI[CloudWatch Insights<br/>Log Analysis]
    end
    
    subgraph "Monitoring & Alerting"
        CWA[CloudWatch Alarms<br/>Threshold Monitoring]
        SNS[SNS Notifications<br/>Alert Delivery]
        DASH[CloudWatch Dashboards<br/>Visualization]
    end
    
    subgraph "Security & Compliance"
        SEC[Security Hub<br/>Compliance Monitoring]
        GUARD[GuardDuty<br/>Threat Detection]
        CONFIG[AWS Config<br/>Configuration Compliance]
    end
    
    %% Data Flow
    SM -->|Session Events| CW
    BH -->|Command History| CW
    EKS -->|API Server Events| CW
    VPC -->|Network Flow Data| CW
    
    SM -->|API Calls| CT
    BH -->|AWS API Calls| CT
    EKS -->|EKS API Calls| CT
    
    CW -->|Log Queries| CWI
    CW -->|Metrics| CWA
    CWA -->|Alerts| SNS
    CW -->|Metrics| DASH
    
    CT -->|Security Events| SEC
    VPC -->|Network Analysis| GUARD
    CW -->|Configuration Data| CONFIG
    
    %% Styling
    classDef source fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef logging fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef monitoring fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef security fill:#ffebee,stroke:#c62828,stroke-width:2px
    
    class SM,BH,EKS,VPC source
    class CW,CT,CWI logging
    class CWA,SNS,DASH monitoring
    class SEC,GUARD,CONFIG security
```

## 🎯 **Key Architecture Benefits**

### ✅ **Security Benefits Visualization**

```mermaid
mindmap
  root((Private Subnet Architecture))
    Network Security
      No Public IPs
      Private Subnets Only
      VPC Endpoints
      NAT Gateway Outbound
    Access Control
      Session Manager Only
      No Direct SSH
      MFA Required
      Cross-Account Roles
    Monitoring
      CloudTrail Logging
      VPC Flow Logs
      Session Logging
      Real-time Alerts
    Compliance
      Account Isolation
      Audit Trails
      Encrypted Storage
      Zero Trust Model
```

This comprehensive diagram set shows:

1. **🏗️ Complete Architecture** - Multi-account layout with all components
2. **🔐 Security Flow** - Step-by-step access authentication and logging
3. **🌐 Network Flow** - Traffic patterns and connectivity rules
4. **🔧 Access Patterns** - How engineers access different environments
5. **📊 Monitoring Flow** - Logging and alerting architecture
6. **🎯 Benefits Mind Map** - Key advantages of the architecture

The diagrams clearly illustrate the zero-trust, private subnet approach with complete isolation and comprehensive monitoring across all three AWS accounts.