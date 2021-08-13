from unittest import mock

import pytest

from qa_ci.ci.get_changelog import main


def test_full(mocker, capsys):
    git_mock = mocker.patch("qa_ci.ci.get_changelog.git")
    repo_mock = mock.Mock()
    git_mock.repo.Repo.return_value = repo_mock
    repo_mock.git.describe.return_value = "rev_desc"
    repo_mock.git.log.return_value = "hash"
    repo_mock.git.show.return_value = (
        "Some change\nSee merge request !10\n[  FLYW  -  2  ]  [FLYW-2] [FLYW-1]"
    )

    main({})

    captured = capsys.readouterr()
    assert captured.out == "- !10 Some change\n    - FLYW-1 FLYW-2\n"


def test_full_no_issues(mocker, capsys):
    git_mock = mocker.patch("qa_ci.ci.get_changelog.git")
    repo_mock = mock.Mock()
    git_mock.repo.Repo.return_value = repo_mock
    repo_mock.git.describe.return_value = "rev_desc"
    repo_mock.git.log.return_value = "hash"
    repo_mock.git.show.return_value = "Some change\nSee merge request !10"

    main({})

    captured = capsys.readouterr()
    assert captured.out == "- !10 Some change\n"


def test_no_mrid(mocker, capsys):
    git_mock = mocker.patch("qa_ci.ci.get_changelog.git")
    repo_mock = mock.Mock()
    git_mock.repo.Repo.return_value = repo_mock
    repo_mock.git.describe.return_value = "rev_desc"
    repo_mock.git.log.return_value = "hash"
    repo_mock.git.show.return_value = (
        "Some change\nSee merge request \n[  FLYW  -  2  ]  [FLYW-2] [FLYW-1]"
    )

    main({})

    captured = capsys.readouterr()
    assert captured.out == "-  Some change\n    - FLYW-1 FLYW-2\n"
