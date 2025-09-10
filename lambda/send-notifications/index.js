import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { v4 as uuidv4 } from "uuid";

const s3 = new S3Client({});
const ses = new SESClient({});
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const bucket = process.env.S3_BUCKET_NAME;
const table = process.env.DYNAMO_TABLE;
const emailSource = process.env.EMAIL_SOURCE;

const getTemplate = async (type) => {
  const key = `${type}.html`;
  const command = new GetObjectCommand({ Bucket: bucket, Key: key });
  const response = await s3.send(command);
  return await streamToString(response.Body);
};

const streamToString = (stream) =>
  new Promise((resolve, reject) => {
    const chunks = [];
    stream.on("data", (chunk) => chunks.push(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
  });

export const handler = async (event) => {
  for (const record of event.Records) {
    try {
      const body = JSON.parse(record.body);
      const { type, data } = body;

      const template = await getTemplate(type);
      let htmlBody = template;

      for (const [key, value] of Object.entries(data)) {
        htmlBody = htmlBody.replace(`{{${key}}}`, value);
      }

      const params = {
        Destination: { ToAddresses: [data.email || "destino@ejemplo.com"] },
        Message: {
          Body: { Html: { Charset: "UTF-8", Data: htmlBody } },
          Subject: { Charset: "UTF-8", Data: `Notificación ${type}` },
        },
        Source: emailSource,
      };

      await ses.send(new SendEmailCommand(params));

      await ddb.send(
        new PutCommand({
          TableName: table,
          Item: {
            uuid: uuidv4(),
            createdAt: new Date().toISOString(),
            type,
            data,
          },
        })
      );

      console.log("Notificación enviada:", type);
    } catch (err) {
      console.error("Error procesando mensaje:", err);
      throw err;
    }
  }
};
