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
        assert fp.read() == ("key1: value1\n" "key2.1: value2.1\n" "key3: value3")


def test_wo_commit_msg(mocker):
    os.environ["FW_RELEASE_COMPONENT"] = "component"

    git_mock = mocker.patch("qa_ci.ci.push_infra_update.git")

    ch_mock = mocker.patch("qa_ci.ci.push_infra_update.mr_chlog_main")
    ch_mock.return_value = 'FW_RELEASE_BRANCH="branch"\nFW_RELEASE_COMMIT="commit msg"'

    replace_mock = mocker.patch("qa_ci.ci.push_infra_update.replace")

    main(["1.2.3"])

    assert replace_mock.mock_calls == [
        mock.call(
            "./release_repo/.gitlab-ci.yml",
            "RELEASECI_component_VERSION:.*",
            "RELEASECI_component_VERSION: 1.2.3",
        )
    ]
    print(git_mock.mock_calls)


def test_w_commit_msg(mocker, caplog):
    os.environ["FW_RELEASE_COMPONENT"] = "component"

    git_mock = mocker.patch("qa_ci.ci.push_infra_update.git")

    ch_mock = mocker.patch("qa_ci.ci.push_infra_update.mr_chlog_main")
    ch_mock.return_value = 'FW_RELEASE_BRANCH="branch"\nFW_RELEASE_COMMIT="commit msg"'

    replace_mock = mocker.patch("qa_ci.ci.push_infra_update.replace")

    main(["1.2.3", "--commit-message", "abc"])
    assert (
        "Could not extract FW_RELEASE_BRANCH and FW_RELEASE_COMMIT, exiting"
        in caplog.text
    )


def test_no_component(mocker, caplog):
    os.environ["FW_RELEASE_COMPONENT"] = ""
    with pytest.raises(SystemExit):
        main(["1.2.3"])
        captured = capsys.readouterr()
        assert "No FW_RELEASE_COMPONENT set, exiting" in caplog.text
