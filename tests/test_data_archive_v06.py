"""Offline contract tests; never connect to a broker or PostgreSQL."""
import json,sys,tempfile,unittest
from datetime import datetime,timezone,timedelta
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from collect_mt5_history_v06 import collect,write_atomic,read_rows
from archive_live_snapshot_v06 import archive_snapshot
from import_history_postgres_v06 import verified_shards

class ArchiveContractTest(unittest.TestCase):
    def test_resume_does_not_download_existing_historical_months(self):
        with tempfile.TemporaryDirectory() as tmp:
            calls=[]
            def provider(start,end):
                calls.append(start.strftime('%Y-%m'))
                t=int(start.timestamp())+3600
                return [{'time':t,'open':1.1,'high':1.2,'low':1.0,'close':1.15,'tick_volume':15}]
            args=SimpleNamespace(output_dir=tmp,symbol='EURUSD',timeframe='H1',years=1,force=False)
            first=collect(args,provider)
            self.assertGreater(first['totalBars'],0)
            initial=set(calls);calls.clear()
            second=collect(args,provider)
            this_month=datetime.now(timezone.utc).strftime('%Y-%m')
            self.assertEqual(calls,[this_month])
            self.assertEqual(first['totalBars'],second['totalBars'])
            root=Path(tmp)/'EURUSD'/'H1'
            manifest,shards=verified_shards(root)
            self.assertEqual(len(shards),len(initial))
            self.assertGreater(second['monthsReadFromArchive'],0)
    def test_short_or_symlinked_archive_path_is_canonicalized(self):
        # Mirrors Windows 8.3 TEMP aliases, where resolving a CSV may expand the
        # parent pathname to its long form. Symlink aliases expose the same bug.
        with tempfile.TemporaryDirectory() as tmp:
            calls=[]
            def provider(start,end):
                calls.append(start.strftime('%Y-%m'))
                return [{'time':int(start.timestamp())+3600,'open':1.1,
                         'high':1.2,'low':1.0,'close':1.15,'tick_volume':15}]
            args=SimpleNamespace(output_dir=tmp,symbol='EURUSD',timeframe='H1',years=1,force=False)
            collect(args,provider)
            original=Path(tmp)/'EURUSD'/'H1'
            original_manifest,original_shards=verified_shards(original)
            self.assertGreater(len(original_shards),0)
            alias=Path(tmp)/'alias-to-h1'
            try:
                alias.symlink_to(original,target_is_directory=True)
            except (OSError,NotImplementedError):
                self.skipTest('Current Windows user cannot create directory symlinks')
            manifest,shards=verified_shards(alias)
            self.assertEqual(manifest['symbol'],original_manifest['symbol'])
            self.assertEqual(len(shards),len(original_shards))
            self.assertTrue(all(path.parent==original.resolve() for _,path,_,_,_ in shards))

    def test_live_archive_merge_and_checksum_integrity(self):
        with tempfile.TemporaryDirectory() as tmp:
            base=Path(tmp)
            snapshot=base/'EURUSD_M15.csv'
            now=int(datetime.now(timezone.utc).timestamp())
            now-=now%900
            one=(now-2700,1.1,1.2,1.0,1.15,20)
            two=(now-1800,1.15,1.25,1.1,1.20,22)
            write_atomic(snapshot,[one,two])
            root,changed,conflicts=archive_snapshot(snapshot,'EURUSD','M15',base/'history')
            self.assertTrue(changed);self.assertEqual(conflicts,0)
            root,changed,conflicts=archive_snapshot(snapshot,'EURUSD','M15',base/'history')
            self.assertEqual(changed,[])
            three=(now-900,1.2,1.3,1.1,1.25,23)
            write_atomic(snapshot,[one,two,three])
            root,changed,conflicts=archive_snapshot(snapshot,'EURUSD','M15',base/'history')
            self.assertEqual(len(changed),1)
            manifest,shards=verified_shards(root)
            self.assertEqual(sum(len(x[-1]) for x in shards),3)
            monthly=root/(changed[0]+'.csv')
            self.assertEqual(len(read_rows(monthly)),3)
            with monthly.open('a',encoding='utf-8') as f:f.write('CORRUPTED\n')
            with self.assertRaises(ValueError):verified_shards(root)
    def test_revisions_keep_previous_shard(self):
        with tempfile.TemporaryDirectory() as tmp:
            base=Path(tmp);snapshot=base/'EURUSD_H1.csv'
            now=int(datetime.now(timezone.utc).timestamp());now-=now%3600
            row=(now-3600,1.1,1.2,1.0,1.15,20)
            write_atomic(snapshot,[row]);root,_,_=archive_snapshot(snapshot,'EURUSD','H1',base/'history')
            modified=(now-3600,1.1,1.2,1.0,1.18,20)
            write_atomic(snapshot,[modified]);_,changed,conflicts=archive_snapshot(snapshot,'EURUSD','H1',base/'history')
            self.assertEqual(conflicts,1);self.assertTrue(changed)
            self.assertEqual(len(list((root/'_revisions').glob('*.csv'))),1)

if __name__=='__main__':unittest.main()
