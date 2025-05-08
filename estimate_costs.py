#!/usr/bin/env python3

import sys
import boto3
import json
import tempfile
import argparse
import urllib.request
from urllib.parse import urlparse
from botocore.exceptions import ClientError


def extract_stack_name(arn):
    """Extract the stack name from a CloudFormation stack ARN."""
    try:
        # ARN format: arn:aws:cloudformation:<region>:<account>:stack/<stack-name>/<id>
        stack_parts = arn.split(':')[-1].split('/')
        if len(stack_parts) >= 2 and stack_parts[0] == 'stack':
            return stack_parts[1]
        return None
    except (IndexError, AttributeError):
        return None


def parse_stack_arns(input_arns):
    """Parse and validate the input stack ARNs."""
    if not input_arns:
        return []

    arns = []
    for arn in input_arns:
        arn = arn.strip()
        if arn and arn.startswith('arn:aws:cloudformation:'):
            stack_name = extract_stack_name(arn)
            if stack_name:
                arns.append(arn)
            else:
                print(f"Warning: Could not extract stack name from ARN: {arn}")
        else:
            print(f"Warning: Invalid CloudFormation stack ARN format: {arn}")

    return arns


def get_template_from_s3(template_url):
    """Download template from S3 and return its local path."""
    parsed_url = urlparse(template_url)
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as temp_file:
        content = urllib.request.urlopen(template_url).read().decode('utf-8')
        temp_file.write(content)
        return temp_file.name


def estimate_stack_cost(arn):
    """Estimate the cost for a CloudFormation stack and return a Cost Explorer URL."""
    try:
        # Extract region from the ARN
        region = arn.split(':')[3]

        # Initialize CloudFormation client for the specific region
        cf_client = boto3.client('cloudformation', region_name=region)

        # Get stack details
        stack_name = extract_stack_name(arn)
        response = cf_client.describe_stacks(StackName=arn)

        if not response or 'Stacks' not in response or len(response['Stacks']) == 0:
            return f"Error: Stack {stack_name} not found"

        stack = response['Stacks'][0]

        # Get template URL or body
        template_response = cf_client.get_template(
            StackName=arn,
            TemplateStage='Original'  # Get the original template without transformations
        )

        # Check if we have a template body or URL
        template_body = template_response.get('TemplateBody')
        template_file = None

        # If we have a template body, write it to a temp file
        if template_body:
            with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as temp_file:
                if isinstance(template_body, str):
                    temp_file.write(template_body)
                elif isinstance(template_body, dict):
                    json.dump(template_body, temp_file)
                temp_file.flush()
                template_file = temp_file.name

        # Get stack parameters
        parameters = []
        if 'Parameters' in stack:
            for param in stack['Parameters']:
                parameters.append({
                    'ParameterKey': param['ParameterKey'],
                    'ParameterValue': param['ParameterValue']
                })

        # Generate estimate using the CloudFormation client
        # We must provide either TemplateBody or TemplateURL, not both
        if template_file:
            with open(template_file, 'r') as f:
                cost_response = cf_client.estimate_template_cost(
                    TemplateBody=f.read(),
                    Parameters=parameters
                )
        else:
            # Try to get template URL from stack details
            template_url = stack.get('TemplateURL')
            if template_url:
                cost_response = cf_client.estimate_template_cost(
                    TemplateURL=template_url,
                    Parameters=parameters
                )
            else:
                return f"Error: Could not retrieve template for stack {stack_name}"

        # Extract and return the Cost Explorer URL
        cost_url = cost_response.get('Url')
        if cost_url:
            return cost_url
        else:
            return f"Error: Could not generate cost URL for {stack_name}"

    except ClientError as e:
        return f"Error: {e}"
    except Exception as e:
        return f"Unexpected error: {e}"


def main():
    """Main function that processes the input and estimates costs for each stack."""
    # Set up argument parser
    parser = argparse.ArgumentParser(
        description='Generate AWS Cost Explorer URLs for CloudFormation stacks',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Example usage:
  python estimate_costs.py arn:aws:cloudformation:region:account-id:stack/stack-name-1 arn:aws:cloudformation:region:account-id:stack/stack-name-2
        '''
    )

    parser.add_argument('stack_arns', metavar='STACK_ARN', type=str, nargs='+',
                        help='One or more CloudFormation stack ARNs')

    args = parser.parse_args()

    # Parse the input ARNs
    stack_arns = parse_stack_arns(args.stack_arns)

    if not stack_arns:
        print("No valid CloudFormation stack ARNs provided.")
        sys.exit(1)

    print(f"Processing {len(stack_arns)} CloudFormation stack(s)...")

    # Process each stack and generate cost URLs
    for arn in stack_arns:
        stack_name = extract_stack_name(arn)
        cost_url = estimate_stack_cost(arn)

        if cost_url.startswith("Error:") or cost_url.startswith("Unexpected error:"):
            print(f"{cost_url}")
        else:
            print(f"Cost Explorer URL for {stack_name}: {cost_url}")


if __name__ == "__main__":
    main()
