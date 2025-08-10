# Form.io Enterprise Configuration

Configuration guide for Form.io Enterprise edition deployment.

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

### Development Environment

The dev environment is configured to use the enterprise edition:

```hcl
use_enterprise = true
formio_version = "9.5.0" 
formio_license_key = "pOHMsV0uoOkfAS6q2jmugmr3Tm5VMt"
```

### Secret Management

The license key is securely stored in Google Secret Manager:

- **Dev Environment**: `dss-formio-api-license-key-dev`

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

## License Validation

### Internet Access Requirement

Form.io Enterprise requires internet access to validate the license with Form.io servers. The deployment uses:

- **Shared VPC**: From `gcp-dss-erlich-infra-terraform`
- **Egress Subnet**: Subnet with internet access via Cloud NAT
- **Firewall Rules**: Allow HTTPS traffic to licensing servers

### Validation Process

1. Form.io Enterprise starts up in Cloud Run
2. Retrieves license key from Secret Manager
3. Contacts Form.io licensing servers via egress subnet
4. Validates license and enables enterprise features
5. Continues normal operation

### Troubleshooting License Issues

#### License Validation Fails
- **Symptom**: Enterprise features not available, license errors in logs
- **Common Causes**:
  - No internet access from Cloud Run
  - Incorrect license key in Secret Manager
  - License expired or invalid
  - Firewall blocking outbound HTTPS traffic

#### Resolution Steps
1. **Check Internet Access**:
   ```bash
   # Test from Cloud Run container
   curl -I https://api.form.io
   ```

2. **Verify License Key**:
   ```bash
   # Check Secret Manager value
   gcloud secrets versions access latest --secret="dss-formio-api-license-key-dev"
   ```

3. **Check License Status**:
   - Login to Form.io portal at https://portal.form.io
   - Verify license is active and not expired
   - Check usage limits

## Enterprise Features

### Available Features

With the enterprise license, the following features are enabled:

- **Advanced Form Components**: Enterprise-only form components
- **Advanced Security**: Enhanced security features
- **Premium Support**: Access to Form.io enterprise support
- **Advanced Analytics**: Enhanced form analytics and reporting
- **Custom Theming**: Advanced customization options
- **API Rate Limits**: Higher API rate limits
- **SLA Guarantees**: Enterprise-level SLA

### Feature Configuration

Enterprise features are automatically enabled when a valid license is detected. No additional configuration is required.

## License Management

### Monitoring License Usage

Monitor license usage through:

1. **Form.io Portal**: https://portal.form.io
   - Login with license administrator account
   - View usage statistics and limits
   - Monitor license expiration

2. **Application Logs**: Check Cloud Run logs for license-related messages
   ```bash
   gcloud run services logs read formio-api-ent --region=us-central1 | grep -i license
   ```

### License Renewal

**Important**: License expires on **08/29/2025**

#### Renewal Process
1. **Contact Form.io**: Reach out to Form.io sales before expiration
2. **Obtain New License**: Receive updated license key
3. **Update Secret**: Store new license key in Secret Manager
4. **Restart Service**: Restart Cloud Run service to use new license

#### Renewal Commands
```bash
# Update license key in Secret Manager
echo "NEW_LICENSE_KEY" | gcloud secrets create dss-formio-api-license-key-dev --data-file=-

# Restart Cloud Run service
gcloud run services replace-traffic formio-api-ent --to-latest --region=us-central1
```

### License Compliance

#### Usage Tracking
- Monitor number of forms and submissions
- Stay within license limits for API calls
- Track active users and concurrent sessions

#### Audit Requirements
- Keep records of license usage
- Document any license changes
- Maintain compliance with Form.io terms

## Security Considerations

### Secret Protection
- License key stored encrypted in Secret Manager
- Access controlled via IAM policies
- Never log license key in plain text
- Rotate access tokens regularly

### Network Security
- License validation traffic encrypted via HTTPS
- Outbound traffic restricted to required endpoints
- VPC provides network isolation
- Firewall rules limit access

## Migration from Community

If migrating from Community edition:

1. **Data Compatibility**: Enterprise edition is backward compatible
2. **Configuration Update**: Update Terraform configuration to use enterprise image
3. **License Configuration**: Add license key to Secret Manager
4. **Feature Activation**: Enterprise features activate automatically
5. **Testing**: Verify all forms and functionality work correctly

## Troubleshooting

### Common Issues

#### "License validation failed" Error
- Check internet connectivity from Cloud Run
- Verify license key in Secret Manager is correct
- Ensure license hasn't expired
- Check firewall rules allow HTTPS outbound

#### Enterprise Features Not Available
- Confirm license validation succeeded
- Check application logs for license status
- Verify enterprise image is being used
- Restart service if needed

#### Performance Issues
- Enterprise edition may have different resource requirements
- Monitor Cloud Run metrics and adjust resources if needed
- Check for license-related API calls impacting performance

### Support Resources

- **Form.io Documentation**: https://help.form.io/deployments/form.io-enterprise-server
- **License Portal**: https://portal.form.io
- **Enterprise Support**: Contact through Form.io portal
- **Technical Issues**: Check Cloud Run and application logs