#!/bin/bash

# set -ex

INITIAL_VERSION=${INITIAL_VERSION:-2.3.0}
TARGET_VERSION=${TARGET_VERSION:-3.3.1}
SCALAFIX_RULES_VERSION=${SCALAFIX_RULES_VERSION:-0.10.4}

prompt () {
  if [ -z "$NO_PROMPT" ]; then
    read -p "Press enter to continue:"
  fi
}

echo "================================="
echo "Build the current project"
sbt clean compile test package




echo "================================="
echo "Now we run the migration setup."

# Sketchy auto rewrite build.sbt
cp -af build.sbt build.sbt.bak

cat build.sbt.bak | \
  python -c 'import re,sys;print(re.sub(r"name :=\s*\"(.*?)\"", "name :=\"\\1-3\"", sys.stdin.read()))' > build.sbt


cat >> build.sbt <<- EOM
scalafixDependencies in ThisBuild +=
  "ch.epfl.scala" %% "scalafix-rules" % "${SCALAFIX_RULES_VERSION}"
semanticdbEnabled in ThisBuild := true
EOM

mkdir -p project
cat >> project/plugins.sbt <<- EOM
addSbtPlugin("ch.epfl.scala" % "sbt-scalafix" % "0.10.4")
EOM

echo "================================="
echo "Verify files before we run scalafix rules"
echo "================================="
prompt

echo "Great! Now we'll try and run the scalafix rules in your project! Yay!. This might fail if you have interesting build targets."
sbt scalafix

echo "================================="
echo "Huzzah running the scalafix-warning check..."

echo "================================="
sbt scalafix ||     (echo "Linter warnings were found"; prompt)


echo "ScalaFix is done, you should probably review the changes (e.g. git diff)"
prompt


# We don't run compile test because some changes are not back compat (see value/key change).
# sbt clean compile test package
cp -af build.sbt build.sbt.bak.pre3
cat build.sbt.bak.pre3 | \
  python -c "import re,sys;print(sys.stdin.read().replace(\"${INITIAL_VERSION}\", \"${TARGET_VERSION}\"))" > build.sbt

echo "================================="
echo "You will also need to update dependency versions now (e.g. Spark to 3.3 and libs)"
echo "Please address those and then press enter."
prompt

echo "================================="
sbt clean compile test package
