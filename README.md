# HelloID-Conn-Prov-Target-Raet-DPIA100-FileAPI

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />

Target connector for creation of DPIA100 through RAET's File API (Beaufort)

This connector contains the DPIA100 target for creating a DPIA100 export for Raet Beaufort to import some generated data from the HelloID provisioning module. This functionality will at one moment be replaced by writing back the desired values by the IAM-API (not supported yet)

This version is created for export only rubriekcode P01035 (emailaddress work)

Please setup the connector following the DPIA100 requirements of the customer. 
You can choose between an export per day, or a DPIA100 export per person.

# API Credentials
In order for this connector to work, access to the File API must be requested at RAET. RAET will supply a new client id / client secret specifically for using the File API. When using the Tenant ID and BusinessTypeID (101020), files should automatically be processed in Beaufort.
