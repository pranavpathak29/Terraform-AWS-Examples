//Ref: https://github.com/awsdocs/aws-lambda-developer-guide/blob/main/sample-apps/blank-nodejs/function/index.js

// Handler
exports.handler = async function(event, context) {
 
  console.log('## CONTEXT: ' + serialize(context))
  console.log('## EVENT: ' + serialize(event))
  if(event.type === "success"){
    return {
      statusCode:200,
      message:"Hello I am success"
    }
  }else{
    throw "Please send to destination." 
  }
  
}

var serialize = function(object) {
  return JSON.stringify(object, null, 2)
}