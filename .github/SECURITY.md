# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

We take the security of Receipt Tracker seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### Please Do Not

- Open a public GitHub issue for security vulnerabilities
- Publicly disclose the vulnerability before it has been addressed

### Please Do

**Report security vulnerabilities via GitHub Security Advisories:**

1. Go to the [Security tab](https://github.com/babushkai/receipt-tracker-ios/security)
2. Click "Report a vulnerability"
3. Fill out the form with details about the vulnerability

**Or email directly:**
- Email: [your-email@example.com]
- Subject: "SECURITY: [Brief description]"

### What to Include

Please provide as much information as possible:

- Type of vulnerability
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the vulnerability
- Any potential workarounds

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: 1-7 days
  - High: 7-30 days
  - Medium: 30-90 days
  - Low: Best effort

### Security Best Practices

When using this app:

1. **API Keys**: Never commit API keys or secrets
2. **Permissions**: Only grant necessary permissions
3. **Updates**: Keep the app updated to the latest version
4. **Data**: Understand that receipts are stored locally
5. **Backups**: Regularly backup your data

### Known Security Considerations

1. **Local Storage**: All data is stored locally using Core Data
2. **OCR Data**: Receipt images and OCR text are stored unencrypted
3. **No Network Sync**: By default, no data leaves the device
4. **LLM Integration**: If enabled, receipt text is sent to third-party APIs

### Security Features

- ✅ Local-first data storage
- ✅ No cloud sync by default
- ✅ Keychain for sensitive data storage (if used)
- ✅ HTTPS-only for API calls
- ✅ Input validation
- ⚠️ Receipt images stored unencrypted (consider device encryption)

### Future Security Enhancements

- [ ] End-to-end encryption for cloud sync
- [ ] Biometric authentication
- [ ] App lock/PIN code
- [ ] Receipt image encryption
- [ ] Certificate pinning

## Disclosure Policy

When we receive a security vulnerability report, we will:

1. Confirm receipt of the vulnerability report
2. Assign severity and impact assessment
3. Work on a fix based on severity
4. Test the fix thoroughly
5. Release the fix in a new version
6. Publicly disclose the vulnerability (after fix is released)

## Hall of Fame

We appreciate security researchers who responsibly disclose vulnerabilities:

<!-- Names will be added here with researcher's permission -->

## Questions?

If you have questions about this security policy, please open a discussion on GitHub.

---

Thank you for helping keep Receipt Tracker secure! 🔒

