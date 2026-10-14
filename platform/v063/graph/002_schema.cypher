// Apply to Neo4j with cypher-shell -f 002_schema.cypher.
CREATE CONSTRAINT currency_code IF NOT EXISTS FOR (c:Currency) REQUIRE c.code IS UNIQUE;
CREATE CONSTRAINT pair_code IF NOT EXISTS FOR (p:CurrencyPair) REQUIRE p.code IS UNIQUE;
CREATE CONSTRAINT factor_id IF NOT EXISTS FOR (f:EconomicFactor) REQUIRE f.id IS UNIQUE;
CREATE CONSTRAINT evidence_id IF NOT EXISTS FOR (e:Evidence) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT relation_observation_id IF NOT EXISTS FOR (o:RelationshipObservation) REQUIRE o.id IS UNIQUE;
