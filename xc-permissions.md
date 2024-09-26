XC Permissions follow a simple nested structure. You assign “roles” to users or groups. Roles are made up of “API Groups” (these are not user configurable – they already exist in the tenant and are sometimes updated/added). “API Groups” consist of “API Elements” which define CRUD permissions against API endpoints.
 
In order to build a role answer these questions:
“What API endpoints does a user need to do the things they want to do?”
“What API elements will allow these actions?”
“Which API groups contain these elements?”

 
Here are the API endpoints needed to manage service discovery in a namespace.
