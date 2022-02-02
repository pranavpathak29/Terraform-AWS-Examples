//Ref: https://github.com/awsdocs/aws-lambda-developer-guide/blob/main/sample-apps/blank-nodejs/function/index.js

const AWSXRay = require("aws-xray-sdk-core");
const AWS = AWSXRay.captureAWS(require("aws-sdk"));
// AWS.config.loadFromPath('./config.json');

const s3 = new AWS.S3({ apiVersion: "2006-03-01" });

// Create client outside of handler to reuse
const lambda = new AWS.Lambda();

// Handler
exports.handler = async function (event, context, callback) {
  console.log("## CONTEXT: " + serialize(context));
  console.log("## EVENT: " + serialize(event));
  const accountSettings = await getAccountSettings();
  const buckets = await getBuckets();
  const response = {
    statusCode: 200,
    statusDescription: "200 OK",
    isBase64Encoded: false,
    headers: {
      "Content-Type": "application/json",
    },
    body: serialize({ accountSettings, buckets }),
  };
  callback(null, response);
};

// Use SDK client
var getAccountSettings = function () {
  return lambda.getAccountSettings().promise();
};

const getBuckets = async function (event, context, callback) {
  const { Buckets } = await s3.listBuckets().promise();
  console.log("## Buckets ", serialize(Buckets));
  return Buckets;
};

var serialize = function (object) {
  return JSON.stringify(object, null, 2);
};
