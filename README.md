# EC2 IMDSv2 Enforcement via EventBridge and Lambda

## 📌 Purpose

This repository implements an automated mechanism to enforce [AWS EC2 Instance Metadata Service v2 (IMDSv2)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html) across all EC2 instances launched within AWS accounts.

It prevents the provisioning of non-compliant instances and terminates any EC2 instance that does not enforce IMDSv2, ensuring alignment with security best practices and compliance requirements.

---

## ✅ What It Does

This solution consists of:

- **EventBridge Rules in All Regions**  
  EventBridge rules capture `RunInstances` API calls (i.e., when a new EC2 is launched) in **every AWS region**.

- **A Central Lambda Function**  
  A single Lambda function (deployed in one region) receives these events and checks the newly launched instance.

- **Enforcement Logic**  
  - If the instance **does not enforce IMDSv2**, the Lambda **automatically terminates** it.
  - If the instance **complies**, no action is taken.

---

## 🚀 Deployment Plan

### 1. **Lambda Function**

The Lambda is deployed in a central region (e.g., `us-east-1`). It:

- Iterates over instance IDs from the event
- Checks metadata options for IMDSv2 enforcement
- Terminates non-compliant instances

You can find the code for the Lambda in [`lambda/terminate_non_imdsv2.py`](./lambda/terminate_non_imdsv2.py).

---

### 2. **EventBridge Rules in All Regions**

For complete coverage, the repository deploys EventBridge rules in every AWS region to detect new EC2 launches. Each rule forwards the event to the central Lambda.

These rules are defined using Terraform with region-specific providers and dynamically deployed using a list of regions.

---

## 🛡️ Why IMDSv2?

IMDSv2 is a hardened version of the EC2 Instance Metadata Service. It mitigates SSRF (Server-Side Request Forgery) and container escape risks by requiring session tokens for metadata access. Enforcing IMDSv2 is a critical step for defense-in-depth in cloud environments.

---
