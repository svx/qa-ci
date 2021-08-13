from unittest import mock
import os
import tempfile

import pytest

from qa_ci.ci.push_infra_update import main, replace


def test_replace():
    tmp = tempfile.NamedTemporaryFile("w")
    tmp.write("key1: value1\nkey2: value2\nkey3: value3")
    tmp.seek(0)

    replace(tmp.name, "key2:.*", "key2.1: value2.1")

    with open(tmp.name) as fp:
        assert fp.read() == (
            "key1: value1\n"
            "key2.1: value2.1\n"
            "key3: value3"
        )
