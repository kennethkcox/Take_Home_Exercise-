import boto3
import argparse
import sys
import time

def get_web_acl(client, name, scope):
    """Get the Web ACL details."""
    try:
        response = client.get_web_acl(Name=name, Scope=scope)
        return response['WebACL'], response['LockToken']
    except client.exceptions.WAFNonexistentItemException:
        print(f"Error: Web ACL '{name}' not found in scope '{scope}'.")
        sys.exit(1)

def push_ip_block(client, web_acl_name, web_acl_scope, ip_to_block):
    """Blocks a given IP/CIDR by adding it to an IP set."""
    print(f"--- Blocking IP: {ip_to_block} ---")
    web_acl, lock_token = get_web_acl(client, web_acl_name, web_acl_scope)

    # This is a simplified example. A real-world script would be more robust.
    # It would likely check if the IP set and rule already exist and update them.
    # For this exercise, we create a new rule for each blocked IP for simplicity.

    ip_set_name = f"{web_acl_name}-IPSet-Block-{int(time.time())}"
    print(f"[*] Creating IP Set: {ip_set_name}")
    ip_set = client.create_ip_set(
        Name=ip_set_name,
        Scope=web_acl_scope,
        IPAddressVersion='IPV4',
        Addresses=[ip_to_block]
    )
    ip_set_arn = ip_set['Summary']['ARN']

    rule_name = f"IPBlockRule-{int(time.time())}"
    print(f"[*] Creating Rule: {rule_name}")
    new_rule = {
        'Name': rule_name,
        'Priority': 0, # Highest priority
        'Action': {'Block': {}},
        'Statement': {
            'IPSetReferenceStatement': {
                'ARN': ip_set_arn
            }
        },
        'VisibilityConfig': {
            'SampledRequestsEnabled': True,
            'CloudWatchMetricsEnabled': True,
            'MetricName': rule_name
        }
    }

    web_acl['Rules'].insert(0, new_rule) # Insert at the beginning for high priority

    print(f"[*] Updating Web ACL: {web_acl_name}")
    try:
        client.update_web_acl(
            Name=web_acl_name,
            Scope=web_acl_scope,
            Id=web_acl['Id'],
            DefaultAction=web_acl['DefaultAction'],
            Description=web_acl.get('Description', ''),
            Rules=web_acl['Rules'],
            VisibilityConfig=web_acl['VisibilityConfig'],
            LockToken=lock_token
        )
        print(f"  [+] SUCCESS: Block rule for {ip_to_block} pushed to {web_acl_name}.")
    except Exception as e:
        print(f"  [-] FAILURE: Could not update Web ACL: {e}")

def push_uri_block(client, web_acl_name, web_acl_scope, uri_pattern):
    """Blocks a given URI pattern by adding it to a Regex Pattern Set."""
    print(f"--- Blocking URI Pattern: {uri_pattern} ---")
    web_acl, lock_token = get_web_acl(client, web_acl_name, web_acl_scope)

    regex_set_name = f"{web_acl_name}-RegexSet-Block-{int(time.time())}"
    print(f"[*] Creating Regex Pattern Set: {regex_set_name}")
    regex_set = client.create_regex_pattern_set(
        Name=regex_set_name,
        Scope=web_acl_scope,
        RegularExpressionList=[{'RegexString': uri_pattern}]
    )
    regex_set_arn = regex_set['Summary']['ARN']

    rule_name = f"URIBlockRule-{int(time.time())}"
    print(f"[*] Creating Rule: {rule_name}")
    new_rule = {
        'Name': rule_name,
        'Priority': 0, # Highest priority
        'Action': {'Block': {}},
        'Statement': {
            'RegexPatternSetReferenceStatement': {
                'ARN': regex_set_arn,
                'FieldToMatch': {'UriPath': {}},
                'TextTransformations': [{'Priority': 0, 'Type': 'NONE'}]
            }
        },
        'VisibilityConfig': {
            'SampledRequestsEnabled': True,
            'CloudWatchMetricsEnabled': True,
            'MetricName': rule_name
        }
    }

    web_acl['Rules'].insert(0, new_rule)

    print(f"[*] Updating Web ACL: {web_acl_name}")
    try:
        client.update_web_acl(
            Name=web_acl_name,
            Scope=web_acl_scope,
            Id=web_acl['Id'],
            DefaultAction=web_acl['DefaultAction'],
            Description=web_acl.get('Description', ''),
            Rules=web_acl['Rules'],
            VisibilityConfig=web_acl['VisibilityConfig'],
            LockToken=lock_token
        )
        print(f"  [+] SUCCESS: Block rule for {uri_pattern} pushed to {web_acl_name}.")
    except Exception as e:
        print(f"  [-] FAILURE: Could not update Web ACL: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Rapidly push block rules to AWS WAFv2.")
    parser.add_argument("--web-acl-name", required=True, help="Name of the Web ACL to update.")
    parser.add_argument("--scope", required=True, choices=['REGIONAL', 'CLOUDFRONT'], help="Scope of the Web ACL.")
    parser.add_argument("--ip", help="IP address or CIDR to block.")
    parser.add_argument("--uri", help="URI string or regex pattern to block.")

    args = parser.parse_args()

    if not args.ip and not args.uri:
        print("Error: You must specify either --ip or --uri.")
        sys.exit(1)

    client = boto3.client('wafv2', region_name="us-east-1") # Specify region

    if args.ip:
        push_ip_block(client, args.web_acl_name, args.scope, args.ip)

    if args.uri:
        push_uri_block(client, args.web_acl_name, args.scope, args.uri)

    print("--- Script Complete ---")
