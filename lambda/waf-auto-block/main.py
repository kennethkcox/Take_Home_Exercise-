import boto3
import os
import json
import logging

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize WAFv2 client
waf_client = boto3.client('wafv2')

# Environment variables
IP_SET_NAME = os.environ.get('IP_SET_NAME')
IP_SET_ID = os.environ.get('IP_SET_ID')
IP_SET_SCOPE = os.environ.get('IP_SET_SCOPE')

def handler(event, context):
    """
    This function is triggered by an SNS notification from a CloudWatch alarm.
    It extracts the IP address from the alarm's trigger data and adds it to a WAF IP set.
    """
    logger.info("Received event: %s", json.dumps(event))

    if not all([IP_SET_NAME, IP_SET_ID, IP_SET_SCOPE]):
        logger.error("Missing required environment variables: IP_SET_NAME, IP_SET_ID, IP_SET_SCOPE")
        return {'statusCode': 500, 'body': 'Configuration error'}

    # Extract the IP address from the SNS message
    # The message body is a JSON string from the CloudWatch alarm
    message = json.loads(event['Records'][0]['Sns']['Message'])
    trigger_data = message['Trigger']

    # The metric namespace and dimensions will contain the IP
    # This assumes the metric is set up to have the IP as a dimension
    ip_to_block = None
    if trigger_data['Namespace'] == 'WAFLogs' and trigger_data['Dimensions']:
        for dimension in trigger_data['Dimensions']:
            if dimension['name'] == 'ClientIP':
                ip_to_block = dimension['value']
                break

    if not ip_to_block:
        logger.error("Could not extract IP address from the event.")
        return {'statusCode': 400, 'body': 'IP address not found in event'}

    logger.info("Attempting to block IP address: %s", ip_to_block)

    try:
        # Get the current IP set to get the lock token
        response = waf_client.get_ip_set(
            Name=IP_SET_NAME,
            Scope=IP_SET_SCOPE,
            Id=IP_SET_ID
        )
        lock_token = response['LockToken']
        current_addresses = response['IPSet']['Addresses']

        # Add the new IP address if it's not already in the set
        if f"{ip_to_block}/32" not in current_addresses:
            current_addresses.append(f"{ip_to_block}/32")

            waf_client.update_ip_set(
                Name=IP_SET_NAME,
                Scope=IP_SET_SCOPE,
                Id=IP_SET_ID,
                LockToken=lock_token,
                Addresses=current_addresses
            )
            logger.info("Successfully added %s to IP Set %s.", ip_to_block, IP_SET_NAME)
        else:
            logger.info("IP %s is already in the IP Set %s. No action taken.", ip_to_block, IP_SET_NAME)

    except Exception as e:
        logger.error("Failed to update WAF IP Set: %s", e)
        raise e

    return {'statusCode': 200, 'body': f'IP {ip_to_block} processed.'}
