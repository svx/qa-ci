from unittest import mock
import os

import pytest

from qa_ci.ci.get_release_mr_details import main


def test_normal(mocker, capsys):
    os.environ["FW_RELEASE_COMPONENT"] = "component"
    os.environ["CI_API_V4_URL"] = "CI_API_V4_URL"
    os.environ["GITLAB_CI_BOT_TOKEN"] = "GITLAB_CI_BOT_TOKEN"

    session_mock = mock.MagicMock()
    mocker.patch(
        "qa_ci.ci.get_changelog_from_mr.requests.Session.__enter__",
        return_value=session_mock,
    )
    resp = mock.Mock()
    resp.ok = True
    resp.json.return_value = [{"source_branch": "source-branch"}]
    session_mock.get.return_value = resp
    main(["1.2.3"])

    captured = capsys.readouterr()
    assert captured.out == (
        '>>>\nFW_RELEASE_BRANCH="source-branch"\n'
        'FW_RELEASE_COMMIT="fix: update component version to 1.2.3"\n>>>\n'
    )


def test_no_component(mocker, caplog):
    os.environ["FW_RELEASE_COMPONENT"] = ""
    main(["1.2.3"])
    assert "No FW_RELEASE_COMPONENT set, exiting" in caplog.text


def test_failed_request(mocker, caplog):
    os.environ["FW_RELEASE_COMPONENT"] = "component"
    os.environ["CI_API_V4_URL"] = "CI_API_V4_URL"
    os.environ["GITLAB_CI_BOT_TOKEN"] = "GITLAB_CI_BOT_TOKEN"

    session_mock = mock.MagicMock()
    mocker.patch(
        "qa_ci.ci.get_changelog_from_mr.requests.Session.__enter__",
        return_value=session_mock,
    )
    resp = mock.Mock()
    resp.ok = False
    resp.content = "error content"
    session_mock.get.return_value = resp

    with pytest.raises(SystemExit):
        main(["1.2.3"])
        assert "Response is not successful: error content" in caplog.text


def test_no_mr(mocker, caplog):
    os.environ["FW_RELEASE_COMPONENT"] = "component"
    os.environ["CI_API_V4_URL"] = "CI_API_V4_URL"
    os.environ["GITLAB_CI_BOT_TOKEN"] = "GITLAB_CI_BOT_TOKEN"

    session_mock = mock.MagicMock()
    mocker.patch(
        "qa_ci.ci.get_changelog_from_mr.requests.Session.__enter__",
        return_value=session_mock,
    )
    resp = mock.Mock()
    resp.ok = True
    resp.json.return_value = []
    session_mock.get.return_value = resp
    main(["1.2.3"])

    assert (
        "No open MR found in flywheel-io%2Finfrastructure%2Frelease repository."
        in caplog.text
    )
