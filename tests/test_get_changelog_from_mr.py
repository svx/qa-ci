from unittest import mock
import os

import pytest

from qa_ci.ci.get_changelog_from_mr import main


def test_normal(mocker, capsys):
    os.environ["CI_COMMIT_MESSAGE"] = "Commit msg !20"
    os.environ["CI_API_V4_URL"] = "CI_API_V4_URL"
    os.environ["CI_PROJECT_ID"] = "CI_PROJECT_ID"
    os.environ["GITLAB_CI_BOT_TOKEN"] = "GITLAB_CI_BOT_TOKEN"

    session_mock = mock.MagicMock()
    mocker.patch(
        "qa_ci.ci.get_changelog_from_mr.requests.Session.__enter__",
        return_value=session_mock,
    )
    resp = mock.Mock()
    resp.ok = True
    resp.json.return_value = [{"description": "Some\nValue\n***\nOther\nValue"}]
    session_mock.get.return_value = resp
    main({})

    captured = capsys.readouterr()
    assert captured.out == "Some\nValue\n"


def test_normal_no_block(mocker, capsys):
    os.environ["CI_COMMIT_MESSAGE"] = "Commit msg !20"
    os.environ["CI_API_V4_URL"] = "CI_API_V4_URL"
    os.environ["CI_PROJECT_ID"] = "CI_PROJECT_ID"
    os.environ["GITLAB_CI_BOT_TOKEN"] = "GITLAB_CI_BOT_TOKEN"

    session_mock = mock.MagicMock()
    mocker.patch(
        "qa_ci.ci.get_changelog_from_mr.requests.Session.__enter__",
        return_value=session_mock,
    )
    resp = mock.Mock()
    resp.ok = True
    resp.json.return_value = [{"description": "Some\nValue"}]
    session_mock.get.return_value = resp
    main({})

    captured = capsys.readouterr()
    assert captured.out == "Some\nValue\n"


def test_normal_full(mocker, capsys):
    os.environ["CI_COMMIT_MESSAGE"] = "Commit msg !20"
    os.environ["CI_API_V4_URL"] = "CI_API_V4_URL"
    os.environ["CI_PROJECT_ID"] = "CI_PROJECT_ID"
    os.environ["GITLAB_CI_BOT_TOKEN"] = "GITLAB_CI_BOT_TOKEN"

    session_mock = mock.MagicMock()
    mocker.patch(
        "qa_ci.ci.get_changelog_from_mr.requests.Session.__enter__",
        return_value=session_mock,
    )
    resp = mock.Mock()
    resp.ok = True
    resp.json.return_value = [{"description": "Some\nValue\n***\nOther\nValue"}]
    session_mock.get.return_value = resp
    main(["-f"])

    captured = capsys.readouterr()
    assert captured.out == "Some\nValue\n***\nOther\nValue\n"


def test_empty_commit(mocker, caplog):
    os.environ["CI_COMMIT_MESSAGE"] = ""
    with pytest.raises(SystemExit):
        main([])
        assert "'CI_COMMIT_MESSAGE' is empty" in caplog.text


def test_failed_request(mocker, caplog):
    os.environ["CI_COMMIT_MESSAGE"] = "Commit msg !20"
    os.environ["CI_API_V4_URL"] = "CI_API_V4_URL"
    os.environ["CI_PROJECT_ID"] = "CI_PROJECT_ID"
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
        main([])
        assert "Response is not successful: error content" in caplog.text


def test_no_mrid(mocker, caplog):
    os.environ["CI_COMMIT_MESSAGE"] = "Commit msg"
    os.environ["CI_API_V4_URL"] = "CI_API_V4_URL"
    os.environ["CI_PROJECT_ID"] = "CI_PROJECT_ID"
    os.environ["GITLAB_CI_BOT_TOKEN"] = "GITLAB_CI_BOT_TOKEN"

    with pytest.raises(SystemExit):
        main([])
        assert "Could not find MR ID in Commit msg" in caplog.text
