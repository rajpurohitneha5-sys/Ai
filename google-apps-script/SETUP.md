# Apps Script gateway setup
1. Create a new Google Apps Script project and paste `Code.gs`.
2. Project Settings -> Script Properties: set `PROVIDER_API_KEY`, `GATEWAY_TOKEN` (long random string), `PROVIDER_BASE_URL` (default OpenAI-compatible API), and `PROVIDER_MODEL`.
3. Deploy -> New deployment -> Web app. Execute as you; choose access carefully. The token gate is in the script.
4. Copy the Web app URL. Android client must use the Apps Script gateway adapter; the current ZIP's Android gateway client targets an OpenAI-compatible HTTP gateway, so Apps Script support is a planned adapter, not connected in this package.
5. Do not share your provider key. Keep it in Script Properties only.
6. Test the health URL with `?action=health`. Authenticated requests currently use query parameter `token` (avoid exposing it in logs or public links; Apps Script limitations mean this is not the ideal production auth design).
