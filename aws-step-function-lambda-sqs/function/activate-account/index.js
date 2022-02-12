//Ref: https://github.com/awsdocs/aws-lambda-developer-guide/blob/main/sample-apps/blank-nodejs/function/index.js


function CustomError(message) {
  this.name = 'CustomError';
  this.message = message;
}
CustomError.prototype = new Error();

// Handler
exports.handler = async function(event, context, callback) {
 
  console.log('## CONTEXT: ' + serialize(context))
  console.log('## EVENT: ' + serialize(event))
  
  callback(null, {...event,isCreated:true, isActivated:true})
  
}

var serialize = function(object) {
  return JSON.stringify(object, null, 2)
}