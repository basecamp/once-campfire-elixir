%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      strict: true,
      checks: %{
        disabled: [
          # Compatibility-heavy code is reviewed and tested directly; forcing arbitrary
          # nesting/complexity limits would encourage semantic churn rather than clarity.
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.Nesting, []}
        ]
      }
    }
  ]
}
