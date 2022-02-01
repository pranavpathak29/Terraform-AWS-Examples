const AWSXRay = require("aws-xray-sdk");
const mysql = AWSXRay.captureMySQL(require("mysql2/promise"));
const secretsManager = require("./secretsManager.js");

let connection;

const defineError = (statusCode, message) => {
  return {
    isBase64Encoded: false,
    statusCode: statusCode,
    body: JSON.stringify({
      "Error Message": message,
    }),
    headers: {
      "Content-Type": "application/json",
    },
  };
};

const save = async (event) => {
  if (!event.data) {
    return defineError(400, "Required parameter not found.");
  }
  const { org_id, emp_id, salary, name } = event.data;
  const query = `INSERT INTO employee(org_id, emp_id,salary,name) VALUES(${org_id},${emp_id},${salary},"${name}")`;
  console.log("Insert Query", query);
  try {
    await connection.execute(query);
    console.log("Success Inserted");
    return {
      statusCode: 200,
      body: {
        message: "Item inserted.",
      },
    };
  } catch (err) {
    console.error("Error insert", err);
    return defineError(500, "Can't insert.");
  }
};

const fetch = async (event) => {
  let query = `select * from employee`;
  if (event.query) {
    const clauses = [];
    Object.keys(event.query).forEach((key) => {
      clauses.push(`${key} = ${event.query[key]}`);
    });

    if (clauses.length > 0) {
      query = `${query} where ${clauses.join(" and ")}`;
    }
  }

  try {
    const [rows] = await connection.execute(query);
    console.log("Data found", rows);
    return {
      statusCode: 200,
      body: {
        message: "Item fetched.",
        data: rows,
      },
    };
  } catch (err) {
    console.error("Error fetch", err);
    return defineError(500, "Can't fetch.");
  }
};

const remove = async (event) => {
  if (!event.query) {
    return defineError(400, "Required parameter not found.");
  }

  let query = `delete from employee`;

  if (event.query) {
    const clauses = [];
    Object.keys(event.query).forEach((key) => {
      clauses.push(`${key} = ${event.query[key]}`);
    });

    if (clauses.length > 0) {
      query = `${query} where ${clauses.join(" and ")}`;
    }
  }

  try {
    await connection.execute(query);

    return {
      statusCode: 200,
      body: {
        message: "Item removed.",
      },
    };
  } catch (err) {
    console.error("Error remove", err);
    return defineError(500, "Can't remove.");
  }
};

const initConnection = async () => {
  if (connection) {
    console.log("Connection Found.");
    return;
  }

  console.log("Connection Not Found.");
  const secrets = await secretsManager.getSecret(
    process.env.SECRET_API_KEY,
    process.env.SECRET_REGION
  );
  const { host, password, port, username, database } = JSON.parse(secrets);

  console.log("Connection Initializing.");
  connection = await mysql.createConnection({
    host: host,
    user: username,
    password: password,
    database: database,
    port: port,
  });

  console.log("Connection established");

  const query = `CREATE TABLE IF NOT EXISTS employee (
    id BIGINT NOT NULL AUTO_INCREMENT,
    org_id INT,
    emp_id INT,
    salary INT,
    name VARCHAR(200),
    PRIMARY KEY (id)
  )`;

  await connection.execute(query);
  console.log("Table created");
};

const handleEvent = async (event) => {
  switch (event.type) {
    case "save":
      return save(event);
    case "fetch":
      return fetch(event);
    case "delete":
      return remove(event);
    default:
      return defineError(400, "Unsupported Operation");
  }
};

exports.handler = async (event, context, callback) => {
  await initConnection();
  console.log("Handling event");
  let res = await handleEvent(event);
  console.log("Response", res);
  return res;
};
