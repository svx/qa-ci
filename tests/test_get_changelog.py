from unittest import mock

import pytest

import qa_ci



def test_args(mocker):
    git_mock = mocker.patch("git")
