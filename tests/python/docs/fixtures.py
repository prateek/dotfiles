import json

from tests.support.python import ROOT, RepoTestCase


ARCHIVED = {"closed": "2026-05-11", "current_guidance": "../current-guide.md"}
SUPERSEDED = {"closed": "2026-05-11", "superseded_by": "../current-guide.md"}
REJECTED = {"closed": "2026-05-11", "status_detail": "No successor."}


class DocsFixture(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.repo = self.work / "repo"
        self.repo.mkdir()
        self.docs = self.repo / "docs"
        self.git("init", "-q", "--initial-branch=main")
        self.git("config", "user.name", "Docs Lifecycle Test")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "commit.gpgSign", "false")
        self.git("config", "maintenance.auto", "false")
        self.doc("current-guide.md", "# Current Guide\n\nCurrent body.", status="current", kind="reference")
        self.index()

    def write(self, relative, text):
        path = self.docs / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def doc(self, relative, body="# Document\n\nBody.", *, status="active", kind="plan", **metadata):
        fields = {"status": status, "doc_type": kind} | metadata
        frontmatter = "\n".join(f"{key}: {json.dumps(value)}" for key, value in fields.items())
        return self.write(relative, f"---\n{frontmatter}\n---\n\n{body}\n")

    def index(self):
        path = self.doc("index.md", "# Documentation Index", status="current", kind="index")
        entries = sorted(item.relative_to(self.docs).as_posix() for item in self.docs.rglob("*.md"))
        with path.open("a") as stream:
            stream.write("\n" + "\n".join(f"- [{name}]({name})" for name in entries) + "\n")

    def validate(self, *, error=None, base=None, docs_root=None, refresh_index=True):
        if refresh_index:
            self.index()
        argv = [str(ROOT / "docs/validate-doc-lifecycle.py"), "--repo-root", str(self.repo)]
        if base:
            argv += ["--base", base]
        if docs_root:
            argv += ["--docs-root", str(docs_root)]
        result = self.command(argv, expected_status=1 if error else 0)
        if error:
            self.assertIn(error, result.stderr.decode())
        else:
            self.assertIn(b"docs lifecycle validation passed", result.stdout)
            self.assertEqual(result.stderr, b"")
        return result

    def git(self, *args, raw=b""):
        return self.command(["git", "-C", str(self.repo), *args], raw, cwd=self.repo).stdout.decode().strip()

    def commit(self, message="fixture"):
        self.index()
        self.git("add", ".")
        self.git("commit", "-q", "--allow-empty", "-m", message)
        return self.git("rev-parse", "HEAD")

    def move(self, before, after):
        (self.docs / after).parent.mkdir(parents=True, exist_ok=True)
        self.git("mv", str(self.docs / before), str(self.docs / after))

    def merge_tree(self, first_parent, second_parent):
        self.index()
        self.git("add", ".")
        tree = self.git("write-tree")
        commit = self.git("commit-tree", tree, "-p", first_parent, "-p", second_parent, raw=b"fixture merge\n")
        self.git("checkout", "-q", "--detach", commit)
        return commit
