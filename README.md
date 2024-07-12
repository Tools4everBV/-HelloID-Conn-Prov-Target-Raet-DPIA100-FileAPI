# HelloID-Conn-Prov-Target-RAET-FileAPI-DPIA100

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Raet-FileAPI-DPIA100/blob/main/Logo.png?raw=true">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-RAET-FileAPI-DPIA100](#helloid-conn-prov-target-RAET-FileAPI-DPIA100)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
      - [Correlation configuration](#correlation-configuration)
      - [Field mapping](#field-mapping)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
  - [Setup the connector](#setup-the-connector)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-RAET-FileAPI-DPIA100_ is a _target_ connector for creation of DPIA100 through RAET's _RAET-FileAPI-DPIA100_ API (Beaufort)

This connector contains the DPIA100 target for creating a DPIA100 export for Raet Beaufort to import some generated data from the HelloID provisioning module. This functionality will at one moment be replaced by writing back the desired values by the IAM-API (not supported yet)

This version is created for export only rubriekcode P01035 (emailaddress work)

Please setup the connector following the DPIA100 requirements of the customer. You can choose between an export per day, or a DPIA100 export per person.

| Endpoint                                | Description           |
| --------------------------------------- | --------------------- |
| https://connect.visma.com/connect/token | Retrieve access token |
| https://fileapi.youforce.com            | DPIA100 endpoint      |

The following lifecycle actions are available:

| Action             | Description                          |
| ------------------ | ------------------------------------ |
| create.ps1         | PowerShell _create_ lifecycle action |
| update.ps1         | PowerShell _update_ lifecycle action |
| configuration.json | Default _configuration.json_         |
| fieldMapping.json  | Default _fieldMapping.json_          |

## Getting started

### Provisioning PowerShell V2 connector

#### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _RAET-FileAPI-DPIA100_ to a person in _HelloID_.

To properly setup the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

   | Setting                   | Value   |
   | ------------------------- | ------- |
   | Enable correlation        | `False` |
   | Person correlation field  | ``      |
   | Account correlation field | ``      |

> [!TIP] > _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

#### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

### Connection settings

The following settings are required to connect to the API.

| Setting                  | Description                                                                                                                                                      | Mandatory |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| DPIA100 FILE PREFIX      | Prefix for Dpia100 file                                                                                                                                          | Yes       |
| DPIA100 CREATIEGEBRUIKER | User used for creating Dpia100 file                                                                                                                              | Yes       |
| DPIA100 PROCESCODE       | Processing code                                                                                                                                                  | Yes       |
| DPIA100 STAM             | Stam code                                                                                                                                                        | Yes       |
| Client ID                | The Client ID to connect with the FileAPI (created when registering the App in in the Visma Developer portal).                                                   | Yes       |
| Client Secret            | The Client Secret to connect with the FileAPI (created when registering the App in in the Visma Developer portal).                                               | Yes       |
| Tenant ID                | The Tenant ID to specify to which Raet tenant to connect with the FileAPI (available in the Visma Developer portal after the invitation code has been accepted). | Yes       |

### Prerequisites

> [!IMPORTANT]
> The latest version of this connector requires **new api credentials**. To get these, please follow the [Visma documentation](https://community.visma.com/t5/Kennisbank-Youforce-API/Visma-Developer-portal-een-account-aanmaken-applicatie/ta-p/527059) on how to register the App and grant access to client data.

- [ ] Enabling of the User endpoints.
  - By default, the User endpoints aren't "enabled". This has to be requested at Raet.
- [ ] File processing.
  - When using the Tenant ID and BusinessTypeID (101020), files should automatically be processed in Beaufort.
- [ ] ClientID, ClientSecret and tenantID
  - Since we are using the API we need the ClientID, ClientSecret and tenantID to authenticate with RAET IAM-API Webservice.
- [ ] Dependent account data in HelloID.
  - Please make your provisioned system dependent on this Users Target Connector and make sure that the values needed to be written back are stored on the account data (e.g UserPrincipalName).

### Remarks

> [!TIP]
> This version is created for export only 'rubriekcode' P01035 (emailaddress work).
>
> When the value in Raet equals the value in HelloID, the action will be skipped (no update will take place).

## Getting help

> [!TIP] > _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP] > _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
