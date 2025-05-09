import boto3

def lambda_handler(event, context):
    ec2_global = boto3.client('ec2')
    regions = [r['RegionName'] for r in ec2_global.describe_regions()['Regions']]

    for region in regions:
        print(f"[INFO] Scanning region: {region}")
        ec2 = boto3.client('ec2', region_name=region)
        try:
            paginator = ec2.get_paginator('describe_instances')
            for page in paginator.paginate(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]):
                for reservation in page['Reservations']:
                    for instance in reservation['Instances']:
                        instance_id = instance['InstanceId']
                        metadata_options = instance.get('MetadataOptions', {})
                        http_tokens = metadata_options.get('HttpTokens', 'optional')

                        print(f"[SCAN] {region} - Instance {instance_id}, IMDSv2: {http_tokens}")
                        if http_tokens != 'required':
                            print(f"[ACTION] Terminating {instance_id} in {region}")
                            try:
                                ec2.terminate_instances(InstanceIds=[instance_id])
                            except Exception as e:
                                print(f"[ERROR] Failed to terminate {instance_id} in {region}: {e}")
        except Exception as e:
            print(f"[ERROR] Failed to scan region {region}: {e}")
