# Form.io Service Architecture

## Overview

This Terraform module deploys Form.io Enterprise and Community services on Google Cloud Platform using **shared infrastructure**. The module does not manage VPC resources - it consumes shared networking infrastructure managed by `gcp-dss-erlich-infra-terraform`.

## Architecture Principles

### Shared Infrastructure Model
- **VPC Management**: All networking resources are managed centrally by `gcp-dss-erlich-infra-terraform`
- **Service Module**: This module focuses on service deployment, not infrastructure
- **Separation of Concerns**: Infrastructure vs. Application deployment are handled separately

### Why Shared VPC?

1. **Service Integration**: Form.io needs to communicate with MongoDB and other services
2. **License Validation**: Form.io Enterprise requires internet egress for license validation
3. **Cost Efficiency**: Single set of network resources (NAT gateways, Cloud Routers)
4. **Security**: Centralized firewall rules and network security management
5. **Simplicity**: No VPC peering or complex cross-network routing

## Network Architecture

```
┌─────────────────────────────────────────────────────────┐
│              erlich-vpc-dev (Shared VPC)                │
│         Managed by: gcp-dss-erlich-infra-terraform     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────┐    ┌─────────────────────────────┐ │
│  │   App Subnet    │    │      Egress Subnet          │ │
│  │  (Private)      │    │    (Internet Access)       │ │
│  │                 │    │                             │ │
│  │ ┌─────────────┐ │    │  ┌─────────────────────────┐ │ │
│  │ │   MongoDB   │ │    │  │      NAT Gateway        │ │ │
│  │ │   Instance  │ │    │  │                         │ │ │
│  │ └─────────────┘ │    │  └─────────────────────────┘ │ │
│  └─────────────────┘    └─────────────────────────────┘ │
│           ↑                           ↑                  │
│           │                           │                  │
│      ┌────┴───────────────────────────┴────┐             │
│      │         VPC Connector               │             │
│      │         (10.8.0.0/28)              │             │
│      │                                    │             │
│      │  ┌──────────────────────────────┐  │             │
│      │  │        Form.io Services      │  │             │
│      │  │   ┌─────────────────────────┐ │  │             │
│      │  │   │  Community Edition     │ │  │             │
│      │  │   │   (Cloud Run)          │ │  │             │
│      │  │   └─────────────────────────┘ │  │             │
│      │  │   ┌─────────────────────────┐ │  │             │
│      │  │   │  Enterprise Edition    │ │  │             │
│      │  │   │   (Cloud Run)          │ │  │             │
│      │  │   └─────────────────────────┘ │  │             │
│      │  └──────────────────────────────┘  │             │
│      └───────────────────────────────────┘             │
└─────────────────────────────────────────────────────────┘
```

## Required Shared Infrastructure

This module requires the following resources from `gcp-dss-erlich-infra-terraform`:

### VPC Network
- **Resource**: `erlich-vpc-dev`
- **Purpose**: Primary network for all services
- **Access**: Read via remote state

### Subnets
- **App Subnet**: Private subnet for MongoDB and other services
- **Egress Subnet**: Internet-enabled subnet for NAT Gateway
- **Connector Subnet**: VPC connector subnet (10.8.0.0/28)

### VPC Connector
- **Resource**: `erlich-vpc-connector-dev`
- **Purpose**: Enable Cloud Run services to access VPC resources
- **Critical For**: MongoDB connectivity and license validation

### Network Security
- **Firewall Rules**: Managed by shared infrastructure
- **NAT Gateway**: Provides controlled internet egress
- **Private Google Access**: For GCP services

## Service Components

### Form.io Community Edition
- **Platform**: Cloud Run
- **Image**: `formio/formio:rc`
- **Database**: MongoDB (shared instance)
- **Storage**: Google Cloud Storage
- **Networking**: VPC Connector for MongoDB access

### Form.io Enterprise Edition
- **Platform**: Cloud Run  
- **Image**: `formio/formio-enterprise:9.5.1-rc.10`
- **License**: Requires internet access for validation
- **Database**: MongoDB (shared instance, separate database)
- **Storage**: Google Cloud Storage
- **Networking**: VPC Connector for MongoDB + license validation

### MongoDB Instance
- **Platform**: Compute Engine
- **Network**: Shared VPC app subnet
- **Access**: Restricted to VPC connector subnet (10.8.0.0/28)
- **Authentication**: Secret Manager managed passwords

## Security Model

### Network Security
- **Private by Default**: All resources in private subnets
- **Controlled Egress**: Only through NAT Gateway for license validation
- **Firewall Rules**: Restrict MongoDB access to VPC connector subnet

### Access Control
- **IAM-Based**: No "allUsers" access permissions
- **Authorized Users**: Specific users granted Cloud Run invoker permissions
- **Service Accounts**: Least privilege access to required secrets

### Secret Management
- **Auto-Generated**: All passwords created by Terraform
- **Secret Manager**: Centralized secret storage
- **Rotation Ready**: Secrets can be rotated without service restart

## Dependencies

### External Dependencies
1. **gcp-dss-erlich-infra-terraform**
   - Must be deployed first
   - Provides VPC, subnets, VPC connector
   - State: `gs://dss-org-tf-state/erlich/dev`

2. **Environment Variables**
   - `TF_VAR_formio_license_key`: Enterprise license key
   - `TF_VAR_formio_root_email`: Admin email address

### Internal Dependencies
- Storage bucket → Form.io services
- MongoDB instance → Form.io services
- Secrets → All services
- VPC connector → Cloud Run deployment

## Migration Notes

### Previous Architecture Issues
- **Dual VPC Problem**: Previously created both local and shared VPC
- **Conditional Logic**: Complex conditional network resource creation
- **Resource Conflicts**: State management issues with mixed VPC usage

### Current Architecture Benefits
- **Single Source of Truth**: Shared VPC managed centrally
- **Clear Dependencies**: Explicit requirement for shared infrastructure
- **Simplified Logic**: No conditional network resource creation
- **Better Testing**: Fail-fast validation for missing shared resources

## Deployment Requirements

### Prerequisites Checklist
- [ ] Shared infrastructure deployed (`gcp-dss-erlich-infra-terraform`)
- [ ] VPC connector accessible from target region
- [ ] Form.io license key available
- [ ] Admin email address configured
- [ ] Appropriate GCP permissions for service deployment

### Validation Commands
```bash
# Verify shared VPC exists
gcloud compute networks describe erlich-vpc-dev --project=erlich-dev

# Verify VPC connector exists  
gcloud compute networks vpc-access connectors describe erlich-vpc-connector-dev \
  --region=australia-southeast1 --project=erlich-dev

# Verify remote state access
terraform console <<< "data.terraform_remote_state.shared_infra.outputs"
```