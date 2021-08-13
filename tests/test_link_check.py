"""Test link checking script."""
import os
import tempfile
from pathlib import Path

import pytest
import requests

os.environ["FORCE_ASCII"] = "true"
from qa_ci.lint.link_check import main  # pylint: disable=wrong-import-position


def test_link_checking_on_regular_file(caplog):
    with tempfile.NamedTemporaryFile() as tmp:
        tmp.write(b"# should work https://flywheel.io\n")
        tmp.write(b"#  https://wrong.io\n")
        tmp.write(b"[`this should not be matched`](test/nothing.py)")
        tmp.seek(0)
        with pytest.raises(SystemExit) as exc:
            main([tmp.name])
            assert exc.value.code == 1
        assert f"OK: {tmp.name}: https://flywheel.io" in caplog.text
        assert f"FAIL: {tmp.name}: https://wrong.io" in caplog.text
        assert "test/nothing.py" not in caplog.text


def test_link_checking_on_markdown_file(caplog):
    with tempfile.NamedTemporaryFile(suffix=".md") as tmp:
        tmp.write(b"[`flywheel`](https://flywheel.io)\n")
        tmp.write(b"[`wrong`](https://wrong.io)\n")
        tmp.write(b"[`this should be matched now`](SOMETHING)\n")
        tmp.write(b"[`missing`](NOTHING)\n")
        tmp.write(b"[`anchor`](#anchor)")
        tmp.seek(0)
        tmp_parent = Path(tmp.name).parent
        with open(f"{tmp_parent}/SOMETHING", mode="w+"):
            with pytest.raises(SystemExit) as exc:
                main([tmp.name])
                assert exc.value.code == 1
        assert f"OK: {tmp.name}: https://flywheel.io" in caplog.text
        assert f"FAIL: {tmp.name}: https://wrong.io" in caplog.text
        assert f"FAIL: {tmp.name}: NOTHING" in caplog.text
        assert f"OK: {tmp.name}: SOMETHING" in caplog.text
        assert f"OK: {tmp.name}: #anchor" in caplog.text


def test_remote_link_server_error(caplog, mocker):
    mocked_head = mocker.patch("requests.Session.head")
    mocked_head.return_value = mocker.MagicMock(status_code=500)
    with tempfile.NamedTemporaryFile() as tmp:
        tmp.write(b"#  https://wrong.io\n")
        tmp.seek(0)
        with pytest.raises(SystemExit) as exc:
            main([tmp.name])
            assert exc.value.code == 1
        assert f"FAIL: {tmp.name}: https://wrong.io" in caplog.text


def test_remote_link_head_error(caplog, mocker):
    mocked_head = mocker.patch("requests.Session.head")

    def raise_timeout(*_, **__):
        raise requests.exceptions.ReadTimeout()

    mocked_head.side_effect = raise_timeout
    with tempfile.NamedTemporaryFile() as tmp:
        tmp.write(b"#  https://flywheel.io")
        tmp.seek(0)
        main([tmp.name])
        assert f"OK: {tmp.name}: https://flywheel.io" in caplog.text


def test_remote_link_head_retry(caplog, mocker):
    mocked_head = mocker.patch("requests.Session.head")
    mocked_head.return_value = mocker.MagicMock(status_code=503)
    with tempfile.NamedTemporaryFile() as tmp:
        tmp.write(b"#  https://flywheel.io")
        tmp.seek(0)
        main([tmp.name])
        assert f"OK: {tmp.name}: https://flywheel.io" in caplog.text

        mocked_get = mocker.patch("requests.get")

        def raise_timeout(*_, **__):
            raise requests.exceptions.ReadTimeout()

        mocked_get.side_effect = raise_timeout
        with pytest.raises(SystemExit) as exc:
            main([tmp.name])
            assert exc.value.code == 1
        assert f"FAIL: {tmp.name}: https://flywheel.io" in caplog.text
