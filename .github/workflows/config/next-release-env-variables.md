# Environment Variables Instructions
At the end of every sprint, when the Release pull request is created, all environment variables configured in the `next-release-env-variables.json` file will be automatically merged into the corresponding `config.properties` or `artifacts.yaml` files for the specified component.

There are three ways to make environment variables changes:

1. If your environment variables changes are backward compatible, you can make the changes directly in the corresponding `config.properties` or `artifacts.yaml` files in all environments at any time.

2. In some cases, environment variable changes *are not* backward compatible and must be applied exactly when the release is promoted to a target environment. To handle this, register your changes in the `next-release-env-variables.json` file. These updates will then be automatically applied when the release pull request is created, ensuring that the environment variable changes are deployed together with the new version of the component.

3. If you need to add or modify an environment variable but don’t know its value—such as an AWS URL generated after running terraform apply—you can still include the variable in the `next-release-env-variables.json` file with the placeholder value **"TBD"**. This ensures the release pull request cannot be merged while environment variables remain unconfigured, as the CI check will fail. Using this process helps flag any missing configurations and serves as a reminder to finalize the environment variable setup before release.

Note that there are CI checks in place that will prevent the release pull request from been merged if there are errors in the `next-release-env-variables.json` file, like invalid target environments, invalid component, wrong json structure, etc.

## Example of a `next-release-env-variables.json` file.

```json
[
  {
    "component": "nexus-backend-account-service",
    "type": "backend",
    "variablesToCreateOrUpdate": [
      {
        "name": "CacheDuration",
        "valuesPerEnvironment": {
          "qa": "0:10",
          "staging-US": "0:50",
          "staging-EU": "0:50",
          "prod-US": "0:50",
          "prod-EU": "0:50"
        }
      },
      {
        "name": "CacheServer",
        "valuesPerEnvironment": {
          "qa": "nexus-elasticache-nonprod-cluster.d377nf.0001.use2.cache.amazonaws.com:6379",
          "staging-US": "tbd",
          "staging-EU": "tbd",
          "prod-US": "tbd",
          "prod-EU": "tbd"
        }
      },
      {
        "name": "Test",
        "valuesPerEnvironment": {
          "qa": "qa-value",
          "staging-US": "use2-value",
          "prod-US": "use2-value",
          "prod-EU": "euc1-value"
        }
      }
    ],
    "variablesToDelete": [
      {
        "name": "AuthDBSecretName",
        "environments": [
          "qa",
          "staging-US",
          "staging-EU",
          "prod-US",
          "prod-EU"
        ]
      }
    ]
  },
  {
    "component": "nexus-ui-host",
    "type": "frontend",
    "variablesToCreateOrUpdate": [
      {
        "name": "COMMON_AGENT_SERVICE_URL",
        "valuesPerEnvironment": {
          "qa": "https://another-eks-server/cas",
          "staging-US": "https://api.echo.intronis.com/abc"
        }
      }
    ],
    "variablesToDelete": [
      {
        "name": "MIXPANEL_TOKEN",
        "environments": [
          "qa",
          "staging-US",
          "staging-EU",
          "prod-US",
          "prod-EU"
        ]
      }
    ]
  }
]
```
