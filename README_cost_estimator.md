# CloudFormation Cost Estimator

This Python script generates AWS Cost Explorer URLs for CloudFormation stacks to help estimate their costs.

## Setup and Usage

1. Set up a virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run the script with CloudFormation stack ARNs:
```bash
python estimate_costs.py arn:aws:cloudformation:region:account-id:stack/stack-name-1 [arn:aws:cloudformation:region:account-id:stack/stack-name-2 ...]
```

## Features

- Parses CloudFormation stack ARNs and validates them
- Retrieves template data (body or URL) from CloudFormation
- Handles both inline templates and S3-stored templates
- Uses the stack's original parameters for accurate cost estimation
- Generates AWS Cost Explorer URLs for easy cost analysis
- Provides clear error messages for troubleshooting

## Notes

- Some CloudFormation resources like AWS::EC2::LaunchTemplate cannot be estimated
- You need appropriate AWS permissions to use this script:
  - cloudformation:DescribeStacks
  - cloudformation:GetTemplate
  - cloudformation:EstimateTemplateCost
- Cost estimates are not available for all resource types
- The script requires AWS credentials to be configured
