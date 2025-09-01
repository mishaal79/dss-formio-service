# Form.io Google Integration Setup Guide

## Overview
This document outlines the manual setup process for integrating Google services (Google Drive, OAuth, Sheets) with Form.io. Due to limitations in both Google's and Form.io's APIs, this integration cannot be fully automated and requires manual configuration through web interfaces.

## Prerequisites
- Access to Google Cloud Console with permissions to create projects and OAuth clients
- Admin access to Form.io project settings
- Form.io Enterprise license (for full feature support)

## Integration Components

### Available Google Integrations
1. **Google Drive Storage** - Store form attachments in Google Drive
2. **Google OAuth** - Allow users to authenticate with Google accounts
3. **Google Sheets** - Export form submissions to Google Sheets
4. **Google APIs** - Access to other Google services via API

## Setup Process

### Part 1: Google Cloud Configuration

#### Step 1: Create Google Cloud Project
1. Navigate to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing project
3. Note the Project ID for reference

#### Step 2: Enable Required APIs
1. Go to **APIs & Services** → **Enable APIs and Services**
2. Enable the following APIs:
   - Google Drive API
   - Google Sheets API
   - Google+ API (if using OAuth for authentication)

#### Step 3: Configure OAuth Consent Screen
1. Navigate to **APIs & Services** → **OAuth consent screen**
2. Choose **External** for user type (or Internal for Google Workspace)
3. Fill in the required information:
   - App name: "DSS Form.io Integration"
   - User support email: [your support email]
   - Developer contact: [your contact email]
4. Add scopes:
   - `https://www.googleapis.com/auth/drive`
   - `https://www.googleapis.com/auth/spreadsheets`
   - `https://www.googleapis.com/auth/userinfo.email`
   - `https://www.googleapis.com/auth/userinfo.profile`
5. Add test users if in testing mode
6. Save and continue

#### Step 4: Create OAuth 2.0 Client ID
1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. Application type: **Web application**
4. Name: "Form.io Integration"
5. Add Authorized redirect URIs:
   - `https://developers.google.com/oauthplayground`
   - Your Form.io instance URL (e.g., `https://forms.dev.cloud.dsselectrical.com.au`)
6. Click **Create**
7. **IMPORTANT**: Save the Client ID and Client Secret securely

#### Step 5: Generate Refresh Token
1. Navigate to [Google OAuth Playground](https://developers.google.com/oauthplayground)
2. Click the gear icon (⚙️) in the top right
3. Check "Use your own OAuth credentials"
4. Enter your Client ID and Client Secret from Step 4
5. In the left panel, select:
   - Google Drive API v3: `https://www.googleapis.com/auth/drive`
   - Google Sheets API v4: `https://www.googleapis.com/auth/spreadsheets`
6. Click "Authorize APIs"
7. Sign in with your Google account and grant permissions
8. Click "Exchange authorization code for tokens"
9. **IMPORTANT**: Copy and save the Refresh Token

### Part 2: Form.io Configuration

#### Step 1: Access Project Settings
1. Log into your Form.io instance
2. Navigate to your project
3. Go to **Settings** (bottom of left navigation)

#### Step 2: Configure Google Drive Integration
1. Navigate to **Settings** → **Integration** → **Data Connections** → **Google Drive**
2. Enter the following:
   - **Client ID**: [From Google Cloud Console Step 4]
   - **Client Secret**: [From Google Cloud Console Step 4]
   - **Refresh Token**: [From OAuth Playground Step 5]
3. Enable **"Auto-refresh token before expiration"**
4. Click **Save Settings**

#### Step 3: Configure Google OAuth (Optional)
1. Navigate to **Authorization** → **OAuth** → **OpenID settings**
2. Add Google as an OAuth provider
3. Configure with your Client ID and Secret
4. Set appropriate scopes for user authentication

#### Step 4: Test the Integration
1. Create a test form with a file upload component
2. Configure the file component to use Google Drive storage
3. Submit a test form with a file
4. Verify the file appears in your Google Drive

## Configuration Storage

### Environment Variables
Store sensitive credentials in environment variables or Secret Manager:

```bash
# Google OAuth Configuration
export GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="your-client-secret"
export GOOGLE_REFRESH_TOKEN="your-refresh-token"
```

### Secret Manager Integration
For production, store these values in Google Secret Manager:

```bash
# Create secrets in Google Secret Manager
gcloud secrets create formio-google-client-id --data-file=- <<< "$GOOGLE_CLIENT_ID"
gcloud secrets create formio-google-client-secret --data-file=- <<< "$GOOGLE_CLIENT_SECRET"
gcloud secrets create formio-google-refresh-token --data-file=- <<< "$GOOGLE_REFRESH_TOKEN"
```

## Limitations and Considerations

### Automation Limitations
- **Google OAuth Client Creation**: No API available, must be done manually through Console
- **Form.io Project Settings**: No API/CLI support for configuration
- **Refresh Token Generation**: Requires interactive OAuth flow

### Security Considerations
- Refresh tokens don't expire but can be revoked
- Store all credentials securely in Secret Manager
- Limit OAuth scopes to minimum required
- Regularly audit Google Drive access logs

### Maintenance Tasks
- Monitor token expiration (if auto-refresh is disabled)
- Review OAuth consent screen warnings
- Update authorized redirect URIs when domains change
- Audit file access permissions in Google Drive

## Troubleshooting

### Common Issues

#### "Invalid Client" Error
- Verify Client ID and Secret are correctly entered
- Check that redirect URIs match exactly
- Ensure OAuth consent screen is configured

#### "Token Expired" Error
- Enable auto-refresh in Form.io settings
- Generate a new refresh token if needed
- Check Google account hasn't revoked access

#### Files Not Appearing in Google Drive
- Verify Google Drive API is enabled
- Check service account permissions
- Ensure correct Google Drive folder permissions

## Alternative OAuth Providers

### Providers with Better Automation Support

#### Auth0
- **Pros**: Full API/Terraform support for configuration
- **Cons**: Additional service to manage, costs
- **Automation**: Can be fully automated via Terraform

#### Okta
- **Pros**: Enterprise-grade, API-driven configuration
- **Cons**: More complex, enterprise pricing
- **Automation**: Terraform provider available

#### AWS Cognito
- **Pros**: Integrated with AWS, Terraform support
- **Cons**: AWS-specific, learning curve
- **Automation**: Full Infrastructure as Code support

#### Azure AD / Microsoft Entra ID
- **Pros**: Enterprise integration, Graph API
- **Cons**: Microsoft ecosystem focused
- **Automation**: Terraform AzureAD provider available

### Recommendation
If automation is critical, consider using Auth0 or Okta as an intermediary OAuth provider that can federate to Google. This allows:
1. Automated OAuth client configuration via Terraform
2. Google authentication through the provider
3. Centralized user management

## Next Steps

- [ ] Complete Google Cloud Project setup
- [ ] Configure OAuth consent screen
- [ ] Create OAuth 2.0 credentials
- [ ] Generate refresh token
- [ ] Configure Form.io integration settings
- [ ] Test file upload to Google Drive
- [ ] Document environment-specific settings
- [ ] Set up monitoring for token expiration

## References

- [Form.io Google Cloud Platform Integration](https://help.form.io/developers/integrations/google-cloud-platform)
- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Google OAuth Playground](https://developers.google.com/oauthplayground)
- [Form.io File Storage Documentation](https://help.form.io/developers/integrations/file-storage)