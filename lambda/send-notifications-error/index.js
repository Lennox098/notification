const AWS = require("aws-sdk");
const DynamoDB = new AWS.DynamoDB.DocumentClient();
const { v4: uuidv4 } = require("uuid");

const table = process.env.ERROR_TABLE;

exports.handler = async (event) => {
  for (const record of event.Records) {
    await DynamoDB.put({
      TableName: table,
      Item: {
        id: uuidv4(),
        body: record.body,
        timestamp: new Date().toISOString()
      }
    }).promise();
  }
};
