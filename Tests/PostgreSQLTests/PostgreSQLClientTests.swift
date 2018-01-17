import Async
import Foundation
import XCTest
@testable import PostgreSQL
import TCP

class PostgreSQLClientTests: XCTestCase {
    func testVersion() throws {
        let (client, eventLoop) = try PostgreSQLClient.makeTest()
        let results = try client.query("SELECT version();").await(on: eventLoop)
        XCTAssert(results[0]["version"]?.string?.contains("10.1") == true)
    }

    func testSelectTypes() throws {
        let (client, eventLoop) = try PostgreSQLClient.makeTest()
        let results = try client.query("select * from pg_type;").await(on: eventLoop)
        XCTAssert(results.count > 350)
    }

    func testParse() throws {
        let (client, eventLoop) = try PostgreSQLClient.makeTest()
        let query = """
        select * from "pg_type" where "typlen" = $1 or "typlen" = $2
        """
        let rows = try client.parameterizedQuery(query, [
            .int32(1),
            .int32(2),
        ]).await(on: eventLoop)

        for row in rows {
            XCTAssert(row["typlen"]?.int == 1 || row["typlen"]?.int == 2)
        }
    }

    func testTypes() throws {
        let (client, eventLoop) = try PostgreSQLClient.makeTest()
        let createQuery = """
        create table kitchen_sink (
            "smallint" smallint,
            "integer" integer,
            "bigint" bigint,
            "decimal" decimal,
            "numeric" numeric,
            "real" real,
            "double" double precision,
            "varchar" varchar(64),
            "char" char(4),
            "text" text,
            "bytea" bytea,
            "timestamp" timestamp,
            "date" date,
            "time" time,
            "boolean" boolean-- ,
            -- "point" point,
            -- "line" line,
            -- "lseg" lseg,
            -- "box" box,
            -- "path" path,
            -- "polygon" polygon,
            -- "circle" circle,
            -- "cidr" cidr,
            -- "inet" inet,
            -- "macaddr" macaddr,
            -- "bit" bit(16),
            -- "uuid" uuid
        );
        """
        _ = try client.query("drop table if exists kitchen_sink;").await(on: eventLoop)
        let createResult = try client.query(createQuery).await(on: eventLoop)
        XCTAssertEqual(createResult.count, 0)

        let insertQuery = """
        insert into kitchen_sink values (
            1, -- "smallint" smallint
            2, -- "integer" integer
            3, -- "bigint" bigint
            4, -- "decimal" decimal
            5, -- "numeric" numeric
            6, -- "real" real
            7, -- "double" double precision
            '9', -- "varchar" varchar(64)
            '10', -- "char" char(4)
            '11', -- "text" text
            '12', -- "bytea" bytea
            now(), -- "timestamp" timestamp
            current_date, -- "date" date
            localtime, -- "time" time
            true -- "boolean" boolean
            -- "point" point,
            -- "line" line,
            -- "lseg" lseg,
            -- "box" box,
            -- "path" path,
            -- "polygon" polygon,
            -- "circle" circle,
            -- "cidr" cidr,
            -- "inet" inet,
            -- "macaddr" macaddr,
            -- "bit" bit(16),
            -- "uuid" uuid
        );
        """
        let insertResult = try client.query(insertQuery).await(on: eventLoop)
        XCTAssertEqual(insertResult.count, 0)
        let selectResult = try client.query("select * from kitchen_sink").await(on: eventLoop)
        if selectResult.count == 1 {
            let row = selectResult[0]
            print(row)
            XCTAssertEqual(row["smallint"], .int16(1))
            XCTAssertEqual(row["integer"], .int32(2))
            XCTAssertEqual(row["bigint"], .int(3))
            XCTAssertEqual(row["decimal"], .double(4))
            XCTAssertEqual(row["real"], .float(6))
            XCTAssertEqual(row["double"], .double(7))
            XCTAssertEqual(row["varchar"], .string("9"))
            XCTAssertEqual(row["char"], .string("10  "))
            XCTAssertEqual(row["text"], .string("11"))
            XCTAssertEqual(row["bytea"], .data(Data([0x31, 0x32])))
            XCTAssertEqual(row["boolean"], .uint8(0x01))
        } else {
            XCTFail("Select count is: \(selectResult.count)")
        }
    }

    /*

 */

    static var allTests = [
        ("testVersion", testVersion),
    ]
}

extension PostgreSQLClient {
    /// Creates a test event loop and psql client.
    static func makeTest() throws -> (PostgreSQLClient, EventLoop) {
        let eventLoop = try DefaultEventLoop(label: "codes.vapor.postgresql.client.test")
        let client = try PostgreSQLClient.connect(on: eventLoop)

        let startup = PostgreSQLStartupMessage.versionThree(parameters: ["user": "postgres"])
        _ = try client.send(.startupMessage(startup)).await(on: eventLoop)
        return (client, eventLoop)
    }
}
