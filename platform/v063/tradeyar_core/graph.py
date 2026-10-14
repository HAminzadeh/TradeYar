"""Idempotent Neo4j seed; structural FX relationships are not probabilistic claims."""
from __future__ import annotations
import os
from .core import safe_symbol, ConfigurationError

CURRENCIES=('USD','EUR','GBP','JPY','CHF','AUD','NZD','CAD')
PAIRS=('EURUSD','GBPUSD','USDJPY','USDCHF','AUDUSD','NZDUSD','USDCAD','EURGBP','EURJPY','GBPJPY','AUDJPY')


def upsert_currency_graph(driver, pairs=PAIRS):
    with driver.session(database=os.getenv('TRADEYAR_NEO4J_DATABASE','neo4j')) as session:
        for pair in pairs:
            pair=safe_symbol(pair)
            if len(pair)!=6 or pair[:3] not in CURRENCIES or pair[3:] not in CURRENCIES:
                raise ValueError('Unsupported pair: '+pair)
            session.run('''MERGE (b:Currency {code:$base}) MERGE (q:Currency {code:$quote})
                           MERGE (p:CurrencyPair {code:$pair})
                           MERGE (p)-[:BASE_CURRENCY]->(b)
                           MERGE (p)-[:QUOTE_CURRENCY]->(q)''',
                        base=pair[:3],quote=pair[3:],pair=pair).consume()
    return len(pairs)


def seed_from_environment():
    try:
        from neo4j import GraphDatabase
    except ImportError as exc:
        raise ConfigurationError('Install neo4j Python driver') from exc
    uri=os.getenv('TRADEYAR_NEO4J_URI','bolt://127.0.0.1:7687')
    user=os.getenv('TRADEYAR_NEO4J_USER','neo4j')
    pwd=os.getenv('TRADEYAR_NEO4J_PASSWORD','')
    if not pwd:
        raise ConfigurationError('Set TRADEYAR_NEO4J_PASSWORD outside Git')
    with GraphDatabase.driver(uri,auth=(user,pwd)) as driver:
        driver.verify_connectivity()
        return upsert_currency_graph(driver)
