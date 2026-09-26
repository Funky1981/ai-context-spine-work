# Jev adapter

This adapter is optional.

Core AI Context Spine functionality does not depend on Jev.

The PowerShell wrapper:
- reads configuration from the local AI Context Spine root
- refuses requests unless external AI and Jev are enabled
- reads the API key only from JEV_API_KEY
- sends a narrow yes/no (noul) decision request to the configured TypeSafe endpoint

The work profile blocks Jev by default. Do not enable it for employer content without explicit approval.

Future adapter versions can add Choice and Score while keeping the same provider-independent boundary.
