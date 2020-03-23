# mvn-init

A very basic maven project initializer. Creates a new mvn project that

- builds a .jar including dependencies on `mvn install`
- makes execution possible via `mvn exec:exec`
- has a source directory with a basic hello world in the given package (creates a subpackage with the given name)

Takes three parameters `mvn-init <project-name> <package> <java-version` e.g. `mvn-init HelloWorld de.olyro 11`.

Build via `cargo build`.
