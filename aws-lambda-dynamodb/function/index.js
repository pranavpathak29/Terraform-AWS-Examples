const AWSXRay = require("aws-xray-sdk-core");
const AWS = AWSXRay.captureAWS(require("aws-sdk"));

const documentClient = new AWS.DynamoDB.DocumentClient();
const tableName = process.env.TableName;

const defineError = (statusCode, message) =>{
  return {
    isBase64Encoded:false,
    statusCode: 500,
    body: JSON.stringify({
      "Error Message": message,
    }),
    headers: {
      "Content-Type": "application/json",
    },
  };
}

const putItem = async (event) => {
  if (!event.data) {
    return defineError(400, "Required parameter not found.");
  }

  try{
    const params =  {
      TableName: tableName,
      Item: {
        org_id: event.data.org_id,
        emp_id: event.data.emp_id,
        emp_name: event.data.emp_name,
        salary: event.data.salary,
      },
    }
    await documentClient.put(params).promise(); 
    console.log("Success Created");
    return {
      statusCode: 200,
      body: {
        message: "Item created."
      },
    }
  }catch(err){
    console.error("Error Create", err);
    return defineError(500, "Can't create.");
  }
};

const scanItem = async(event) => {
  try{
    const params = {
      TableName: tableName,
    }
    const data = await documentClient.scan(params).promise(); 
    return {
      statusCode: 200,
      body: {
        message: "Item scanned.",
        data: data.Items,
      },
    }
  }catch(err){
    console.error("Error Scan", err);
    return defineError(500, "Can't scan.");
  }
};

const queryItem = async (event) => {

  try{
    const params = {
      ExpressionAttributeValues: {
        ":org_id": event.query.org_id,
      },
      TableName: tableName,
      KeyConditionExpression: "org_id = :org_id",
      ProjectionExpression: "org_id, emp_id, salary",
    }
    const data = await documentClient.query(params).promise(); 
    return {
      statusCode: 200,
      body: {
        message: "Item queried.",
        data: data.Items,
      },
    }
  }catch(err){
    console.error("Error Query", err);
    return defineError(500, "Can't query.");
  }
};

const deleteItem = async (event) => {
  try{
    const params = {
      TableName: tableName,
      Key: {
        org_id: event.query.org_id,
        emp_id: event.query.emp_id,
      },
    }
    await documentClient.delete(params).promise(); 
    return {
      statusCode: 200,
      body: {
        message: "Item deleted."
      },
    }
  }catch(err){
    console.error("Error Delete", err);
    return defineError(500, "Can't deleted.");
  }
};

const handleEvent = (event) =>{
  switch (event.type) {
    case "PutItem":
      return putItem(event);
    case "ScanItem":
      return scanItem(event);
    case "QueryItem":
      return queryItem(event);
    case "DeleteItem":
      return deleteItem(event);
    default:
      return defineError(400, "Unsupported Operation")
  }
}

exports.handler = async (event, context,callback) => {
  let res =await handleEvent(event);
 
  if(res.statusCode>=200 && res.statusCode<=299){
    callback(null ,res);
  }else{
    callback(JSON.stringify(res), null)
  }
};
