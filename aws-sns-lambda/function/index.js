//Ref: https://github.com/awsdocs/aws-lambda-developer-guide/blob/main/sample-apps/blank-nodejs/function/index.js

// Handler
exports.handler = async function (event, context) {
  console.log("## CONTEXT: " + serialize(context));
  console.log("## EVENT: " + serialize(event));

  return {
    statusCode: 200,
    body: "Success",
  };
};

var serialize = function (object) {
  return JSON.stringify(object, null, 2);
};
