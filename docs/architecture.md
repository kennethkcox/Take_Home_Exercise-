```mermaid
graph TD
    subgraph "GitHub"
        direction LR
        A[Developer] -->|git push| B(GitHub Repo);
        B -->|Pull Request| C{Edge CI Workflow};
        C -->|terraform plan| B;
        B -->|Merge to main| D{Edge CD Workflow};
    end

    subgraph "AWS Account"
        direction TB

        subgraph "CI/CD Pipeline"
            D --> E[Terraform Apply];
        end

        subgraph "Edge Security Platform"
            direction LR
            F[Internet] --> G(CloudFront);
            G --> H(Lambda@Edge);
            H --> I(AWS WAF);
            I --> J[Application Load Balancer];
        end

        subgraph "Application"
            J --> K(ECS Fargate);
            K --> L[Juice Shop Container];
        end

        subgraph "Automated Defense Loop"
            direction TB
            I -->|Logs| M(Kinesis Firehose);
            M --> N[S3 Bucket];
            N -->|Logs| O(CloudWatch Logs);
            O -->|Metric Filter| P(CloudWatch Alarm);
            P -->|Trigger| Q(SNS Topic);
            Q -->|Invoke| R{Auto-Block Lambda};
            R -->|UpdateIPSet| I;
        end
    end

    style C fill:#00A4EF,stroke:#333,stroke-width:2px
    style D fill:#00A4EF,stroke:#333,stroke-width:2px
    style R fill:#FF9900,stroke:#333,stroke-width:2px
    style H fill:#FF9900,stroke:#333,stroke-width:2px
```
