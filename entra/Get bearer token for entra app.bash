#!/bin/bash
curl --location 'https://login.microsoftonline.com/<TENANT-ID>/oauth2/v2.0/token' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode 'client_id=<CLIENT-ID>' \
--data-urlencode 'client_secret=<CLIENT_SECRET>' \
--data-urlencode 'scope=https://graph.microsoft.com/.default' \
--data-urlencode 'grant_type=client_credentials'
