# Manual/Device Validation Plan for PR #41 Merge

## A. Build/Flash Verification
- **Test**: Verify that the firmware builds successfully without errors.
- **Curl Command**: `curl -X GET http://<device_ip>/firmware`  
- **Pass/Fail Criteria**: The command should return a valid firmware version.

## B. Endpoint Sanity
- **Test**: Check that all expected API endpoints are functional.
- **Curl Command**: `curl -X GET http://<device_ip>/api/status`  
- **Pass/Fail Criteria**: HTTP status 200 on all endpoints.

## C. Manual Heavy-Route Stability
- **Test**: Instruct heavy traffic to a key route.
- **Curl Command**: `curl -X GET http://<device_ip>/api/data?type=heavy`  
- **Pass/Fail Criteria**: No dropped requests or timeouts.

## D. SSE Tests
- **Test**: Subscribe to Server Sent Events.
- **Curl Command**: `curl -N http://<device_ip>/api/events`  
- **Pass/Fail Criteria**: Event stream should not disconnect unexpectedly.

## E. Polling Tests
- **Test**: Validate data polling integrity.
- **Curl Command**: `curl -X GET http://<device_ip>/api/poll`  
- **Pass/Fail Criteria**: Data returned is consistent across polling requests.

## F. History-Loading Behavior
- **Test**: Check how history events load over time.
- **Curl Command**: `curl -X GET http://<device_ip>/api/history`  
- **Pass/Fail Criteria**: Correct historical data returned.

## G. Storage Stats Timing
- **Test**: Measure the time to retrieve storage statistics.
- **Curl Command**: `curl -X GET http://<device_ip>/api/storage/stats`  
- **Pass/Fail Criteria**: Timing within acceptable limits.

## H. Long-Run Stability
- **Test**: Let the system run for an extended period and monitor.
- **Curl Command**: N/A  
- **Pass/Fail Criteria**: System remains responsive and efficient over 24 hours.

## I. Repeatability/Reopen Testing
- **Test**: Restart the device and repeat previous tests to ensure consistency.
- **Curl Command**: N/A  
- **Pass/Fail Criteria**: All tests should yield the same results after reboot.