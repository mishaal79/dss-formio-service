# Form.io Enterprise Configuration

This document explains how the Form.io Enterprise edition is configured in this infrastructure deployment.

## License Information

- **License Key**: `pOHMsV0uoOkfAS6q2jmugmr3Tm5VMt`
- **License Owner**: mishal@qrius.global
- **Start Date**: 07/28/2025
- **End Date**: 08/29/2025
- **Configuration**: One (1) Enterprise Level project, Two (2) API Server Environments

## Docker Image Configuration

- **Enterprise Image**: `formio/formio-enterprise:9.5.0`
- **Repository**: https://hub.docker.com/repository/docker/formio/formio-enterprise

## Environment Configuration

### All Environments (Dev/Staging/Prod)
All environments are configured to use the enterprise edition:

```hcl
use_enterprise = true
formio_version = "9.5.0" 
formio_license_key = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMt"
```

### Secret Management
The license key is securely stored in Google Secret Manager for each environment:

- `dss-formio-api-license-key-dev`
- `dss-formio-api-license-key-staging` 
- `dss-formio-api-license-key-prod`

### Environment Variables
The Cloud Run service receives the license key via environment variable:

```hcl
env {
  name = "LICENSE_KEY"
  value_source {
    secret_key_ref {
      secret  = google_secret_manager_secret.formio_license_key[0].secret_id
      version = "latest"
    }
  }
}
```

## Enterprise Features Enabled

With the enterprise license, the following features are available:

1. **Enterprise API Server**: Full enterprise feature set
2. **Advanced Form Components**: Enterprise-only form components
3. **Enhanced Security**: Additional security features
4. **Premium Support**: Access to enterprise support channels
5. **Advanced Analytics**: Enhanced reporting and analytics capabilities

## License Management

- **Portal Access**: License administrators can manage the license at https://help.form.io/deployments/license-management
- **Monitoring**: License usage is monitored across environments
- **Renewal**: License expires on 08/29/2025 and will need renewal

## Deployment Validation

To validate enterprise configuration is working:

1. **Check Service Logs**: Enterprise features should be available in logs
2. **Access Admin Portal**: Admin portal should show enterprise features
3. **Test Enterprise Components**: Verify enterprise-only components work
4. **License Status**: Check license status in Form.io admin interface

## Troubleshooting

### License Issues
If license validation fails:

1. Verify license key in Secret Manager
2. Check Cloud Run service logs for license errors
3. Ensure proper environment variable configuration
4. Validate license hasn't expired

### Image Issues
If enterprise image fails to deploy:

1. Verify access to enterprise Docker repository
2. Check image tag is correct (`formio/formio-enterprise:9.5.0`)
3. Ensure proper authentication for enterprise registry

## Cost Considerations

- **License Cost**: Enterprise license provides significant value over community edition
- **Infrastructure Cost**: Same infrastructure cost as community edition
- **Feature Value**: Enterprise features justify additional licensing cost
- **Support Value**: Premium support reduces operational overhead

## Migration from Community

If migrating from community edition:

1. Update `use_enterprise = true` in environment configurations
2. Deploy with enterprise license key
3. Verify all enterprise features are working
4. Update any custom integrations to use enterprise APIs

## Security Notes

- License key is stored securely in Secret Manager
- No license key hardcoded in source code
- Access to license managed via IAM permissions
- Regular rotation of secrets recommended

## References

- [Form.io Enterprise Documentation](https://help.form.io/deployments/form.io-enterprise-server)
- [General Deployment Guide](https://help.form.io/deployments/deployment-guide/)
- [License Management](https://help.form.io/deployments/license-management)