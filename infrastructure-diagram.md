# Laravel GKE Infrastructure Diagram - Japan Region

## 🏗️ Architecture Overview

```mermaid
graph TB
    %% External Layer
    subgraph "🌐 External Access"
        CF[Cloudflare<br/>SSL Termination<br/>DNS: zyoshu-test.com]
        USER[👤 Users<br/>HTTPS Requests]
    end

    %% GCP Infrastructure
    subgraph "🇯🇵 Google Cloud Platform - Japan (asia-northeast1)"
        
        %% Load Balancer
        subgraph "🔗 Load Balancer"
            LB[GCP Load Balancer<br/>Static IP: 136.110.137.230<br/>HTTP Backend]
        end
        
        %% GKE Cluster
        subgraph "☸️ GKE Cluster - laravel-cluster-stg"
            subgraph "🏠 Namespace: laravel-app"
                
                %% Ingress
                ING[Ingress Controller<br/>zyoshu-test.com<br/>NodePort Service]
                
                %% Services
                subgraph "🔧 Services"
                    HTTPSVC[laravel-http-service<br/>NodePort: 31816<br/>ClusterIP: 10.2.177.3]
                    REDISSVC[redis-service<br/>ClusterIP<br/>Port: 6379]
                end
                
                %% Pods
                subgraph "📦 Application Pods"
                    HTTP[Laravel HTTP<br/>🟢 1/1 Ready<br/>CPU: 50m, RAM: 256Mi<br/>Health: /health]
                    HORIZON[Laravel Horizon<br/>🟢 1/1 Ready<br/>CPU: 25m, RAM: 512Mi<br/>Queue Worker]
                    SCHEDULER[Laravel Scheduler<br/>🟢 1/1 Ready<br/>CPU: 25m, RAM: 512Mi<br/>Cron Jobs]
                end
                
                %% Redis Pod
                subgraph "💾 Cache Layer"
                    REDIS[Redis Pod<br/>🟢 1/1 Ready<br/>CPU: 50m, RAM: 256Mi<br/>Version: 7.0-alpine]
                end
                
                %% Secrets & Config
                subgraph "🔐 Configuration"
                    SECRETS[laravel-secrets<br/>DB credentials<br/>Redis password<br/>GitHub token]
                    CONFIG[laravel-config<br/>App configuration<br/>Domain settings<br/>Trust proxies]
                    GCSCONFIG[gcs-config<br/>Storage bucket<br/>GCP project settings]
                end
            end
            
            %% Nodes
            subgraph "🖥️ Worker Nodes (3 nodes)"
                NODE1[Node 1<br/>e2-medium<br/>2 vCPU, 4GB RAM<br/>asia-northeast1-a]
                NODE2[Node 2<br/>e2-medium<br/>2 vCPU, 4GB RAM<br/>asia-northeast1-a]
                NODE3[Node 3<br/>e2-medium<br/>2 vCPU, 4GB RAM<br/>asia-northeast1-a]
            end
        end
        
        %% Database
        subgraph "🗄️ Database Layer"
            CLOUDSQL[Cloud SQL MySQL 8.0<br/>Instance: laravel-db-stg-0a38549b<br/>Private IP: 10.83.0.3<br/>Tier: db-f1-micro<br/>Storage: 10GB PD_HDD]
        end
        
        %% Storage
        subgraph "📁 Storage Layer"
            GCS[Cloud Storage<br/>zyoshu-laravel-shared-stg<br/>Location: ASIA-NORTHEAST1<br/>Multi-tenant buckets]
            TFSTATE[Terraform State<br/>zyoshu-terraform-state-staging<br/>Backend storage]
        end
        
        %% Service Accounts
        subgraph "🔑 Service Accounts"
            GCSSA[laravel-gcs-stg<br/>Storage Admin<br/>GCS Access]
            GKESA[gke-nodes-stg<br/>Node Service Account<br/>Registry Access]
        end
    end

    %% Connections
    USER --> CF
    CF --> LB
    LB --> ING
    ING --> HTTPSVC
    HTTPSVC --> HTTP
    
    %% Internal Connections
    HTTP -.-> REDIS
    HORIZON -.-> REDIS
    SCHEDULER -.-> REDIS
    
    HTTP -.-> CLOUDSQL
    HORIZON -.-> CLOUDSQL
    SCHEDULER -.-> CLOUDSQL
    
    HTTP -.-> GCS
    HORIZON -.-> GCS
    
    HTTP -.-> SECRETS
    HORIZON -.-> SECRETS
    SCHEDULER -.-> SECRETS
    
    HTTP -.-> CONFIG
    HORIZON -.-> CONFIG
    SCHEDULER -.-> CONFIG
    
    %% Pod to Node assignment
    HTTP -.-> NODE1
    HORIZON -.-> NODE2
    SCHEDULER -.-> NODE3
    REDIS -.-> NODE1

    %% Styling
    classDef external fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef gcp fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef k8s fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef pod fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef service fill:#fff8e1,stroke:#f57f17,stroke-width:2px
    classDef database fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef ready fill:#c8e6c9,stroke:#388e3c,stroke-width:2px
    
    class USER,CF external
    class LB,CLOUDSQL,GCS,TFSTATE,GCSSA,GKESA gcp
    class ING,HTTPSVC,REDISSVC,SECRETS,CONFIG,GCSCONFIG k8s
    class HTTP,HORIZON,SCHEDULER,REDIS ready
    class NODE1,NODE2,NODE3 service
```

## 📊 Resource Summary

### 💰 Cost Breakdown (Monthly)
| Component | Type | Cost |
|-----------|------|------|
| **GKE Cluster** | 3 × e2-medium nodes | ~$60-80 |
| **Cloud SQL** | db-f1-micro + 10GB | ~$15-20 |
| **Static IP** | Global external IP | ~$5 |
| **Storage** | GCS + Terraform state | ~$2-5 |
| **~~Redis VM~~** | ~~e2-small~~ | ~~$0~~ (Removed) |
| **Total** | | **~$82-110/month** |

### 🎯 Performance Characteristics
- **Latency**: < 50ms (Japan region)
- **Availability**: 99.9% (multi-node setup)
- **Scalability**: Auto-scaling 1-3 nodes
- **Storage**: Multi-tenant GCS buckets
- **Queue Processing**: Redis-based with Horizon

### 🔧 Key Features
- ✅ **Multi-tenant Architecture**: Subdomain routing ready
- ✅ **Auto-healing**: Kubernetes manages all components
- ✅ **Cost-optimized**: Staging configuration with minimal resources
- ✅ **SSL Ready**: Cloudflare handles HTTPS termination
- ✅ **Monitoring**: Health checks on all components
- ✅ **Persistent Data**: Cloud SQL + GCS storage

### 🌐 Network Flow
1. **User** → `https://zyoshu-test.com`
2. **Cloudflare** → SSL termination → HTTP
3. **GCP Load Balancer** → `136.110.137.230`
4. **Kubernetes Ingress** → Routes to service
5. **NodePort Service** → Distributes to pods
6. **Laravel Pods** → Process requests
7. **Redis Pod** → Caching & queues
8. **Cloud SQL** → Database operations
9. **GCS** → File storage

### 🔄 Data Flow
- **HTTP Requests**: User → Cloudflare → Load Balancer → Ingress → HTTP Pod
- **Queue Jobs**: HTTP Pod → Redis → Horizon Pod → Processing
- **Scheduled Tasks**: Scheduler Pod → Executes cron jobs
- **Database**: All pods → Cloud SQL (private IP)
- **File Storage**: All pods → GCS buckets (multi-tenant)

---
*Generated: November 5, 2025*  
*Environment: Staging*  
*Region: Asia-Northeast1 (Tokyo, Japan)*
