{
  "Comment": "A example of the Amazon States Language to create account",
  "StartAt": "CreateAccount",
  "States": {
    "CreateAccount": {
      "Type": "Task",
      "Resource": "${create_account_function_arn}",
      "Catch": [
        {
          "ErrorEquals": ["CustomError"],
          "Next": "CustomErrorFallback"
        },
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "CatchAllFallback"
        }
      ],
      "Next": "Is account created?"
    },
    "CustomErrorFallback": {
      "Type": "Pass",
      "Next": "Account not created",
      "Parameters": {
        "error.$": "States.StringToJson($.Cause)"
      }
    },
    "CatchAllFallback": {
      "Type": "Pass",
      "Parameters": {
        "message": "Something goes wrong"
      },
      "Next": "Account not created"
    },
    "Is account created?": {
      "Comment": "Check whether account is created or not.",
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.isCreated",
          "BooleanEquals": true,
          "Next": "Wait 3 sec to notify"
        },
        {
          "Variable": "$.isCreated",
          "BooleanEquals": false,
          "Next": "Account not created"
        }
      ],
      "Default": "Account not created"
    },
    "Wait 3 sec to notify": {
      "Comment": "Wait for 3 sec and then send a mail and ",
      "Type": "Wait",
      "Seconds": 3,
      "Next": "Post Account Creation"
    },
    "Post Account Creation": {
      "Comment": "Execute post account creation steps.",
      "Type": "Parallel",
      "End": true,
      "Branches": [
        {
          "StartAt": "Activate Account",
          "States": {
            "Activate Account": {
              "Type": "Task",
              "Resource": "${activate_account_function_arn}",
              "End": true
            }
          }
        },
        {
          "StartAt": "Send Email to Admin",
          "States": {
            "Send Email to Admin": {
              "Type": "Task",
              "Resource": "arn:aws:states:::sns:publish",
              "Parameters": {
                "TopicArn": "${admin_topic_arn}",
                "Message.$": "States.Format('Hello, user is registered with email {}.', $.email)",
                "MessageAttributes": {
                  "email": {
                    "DataType": "String",
                    "StringValue.$": "$.email"
                  }
                }
              },
              "End": true
            }
          }
        }
      ]
    },
    "Account not created": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "${failure_topic_arn}",
        "Message.$": "$.error"
      },
      "End": true
    }
  }
}
