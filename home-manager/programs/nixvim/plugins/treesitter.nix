{
  treesitter = {
    enable = true;

    nixvimInjections = true;

    folding = false;
    indent = true;
  };

  treesitter-refactor = {
    enable = true;
    highlightDefinitions.enable = true;
  };

  treesitter-textobjects = {
    enable = true;
    select = {
      enable = true;
      lookahead = true;
      keymaps = {
        "a=" = {
          query = "@assignment.outer";
          desc = "Select outer part of an assignment";
        };
        "i=" = {
          query = "@assignment.inner";
          desc = "Select inner part of an assignment";
        };
        "v" = {
          query = "@assignment.lhs";
          desc = "Select left hand side of an assignment";
        };
        "V" = {
          query = "@assignment.rhs";
          desc = "Select right hand side of an assignment";
        };

        "aa" = {
          query = "@parameter.outer";
          desc = "Select outer part of a parameter/argument";
        };
        "ia" = {
          query = "@parameter.inner";
          desc = "Select inner part of a parameter/argument";
        };

        "ai" = {
          query = "@conditional.outer";
          desc = "Select outer part of a conditional";
        };
        "ii" = {
          query = "@conditional.inner";
          desc = "Select inner part of a conditional";
        };

        "al" = {
          query = "@loop.outer";
          desc = "Select outer part of a loop";
        };
        "il" = {
          query = "@loop.inner";
          desc = "Select inner part of a loop";
        };

        # "af" = {
        #   query = "@call.outer";
        #   desc = "Select outer part of a function call";
        # };
        # "if" = {
        #   query = "@call.inner";
        #   desc = "Select inner part of a function call";
        # };

        "af" = {
          query = "@function.outer";
          desc = "Select outer part of a method/function definition";
        };
        "if" = {
          query = "@function.inner";
          desc = "Select inner part of a method/function definition";
        };

        "ac" = {
          query = "@class.outer";
          desc = "Select outer part of a class";
        };
        "ic" = {
          query = "@class.inner";
          desc = "Select inner part of a class";
        };
      };
    };
    swap = {
      enable = true;
      swapNext = {
        "<leader>na" = {
          query = "@parameter.inner";
          desc = "swap parameters/argument with next";
        };
        "<leader>nf" = {
          query = "@function.outer";
          desc = "swap function with next";
        };
      };
      swapPrevious = {
        "<leader>pa" = {
          query = "@parameter.inner";
          desc = "swap parameters/argument with prev";
        };
        "<leader>pf" = {
          query = "@function.outer";
          desc = "swap function with previous";
        };
      };
    };
    move = {
      enable = true;
      setJumps = true; # whether to set jumps in the jumplist
      gotoNextStart = {
        # "]f" = {
        #   query = "@call.outer";
        #   desc = "Next function call start";
        # };
        "]f" = {
          query = "@function.outer";
          desc = "Next method/function def start";
        };
        "]c" = {
          query = "@class.outer";
          desc = "Next class start";
        };
        "]i" = {
          query = "@conditional.outer";
          desc = "Next conditional start";
        };
        "]l" = {
          query = "@loop.outer";
          desc = "Next loop start";
        };

        "]o" = {
          query = "@scope";
          queryGroup = "locals";
          desc = "Next scope";
        };
        "]z" = {
          query = "@fold";
          queryGroup = "folds";
          desc = "Next fold";
        };
      };
      gotoNextEnd = {
        # "]F" = {
        #   query = "@call.outer";
        #   desc = "Next function call end";
        # };
        "]F" = {
          query = "@function.outer";
          desc = "Next method/function def end";
        };
        "]C" = {
          query = "@class.outer";
          desc = "Next class end";
        };
        "]I" = {
          query = "@conditional.outer";
          desc = "Next conditional end";
        };
        "]L" = {
          query = "@loop.outer";
          desc = "Next loop end";
        };
      };
      gotoPreviousStart = {
        # "[f" = {
        #   query = "@call.outer";
        #   desc = "Prev function call start";
        # };
        "[f" = {
          query = "@function.outer";
          desc = "Prev method/function def start";
        };
        "[c" = {
          query = "@class.outer";
          desc = "Prev class start";
        };
        "[i" = {
          query = "@conditional.outer";
          desc = "Prev conditional start";
        };
        "[l" = {
          query = "@loop.outer";
          desc = "Prev loop start";
        };
      };
      gotoPreviousEnd = {
        # "[F" = {
        #   query = "@call.outer";
        #   desc = "Prev function call end";
        # };
        "[F" = {
          query = "@function.outer";
          desc = "Prev method/function def end";
        };
        "[C" = {
          query = "@class.outer";
          desc = "Prev class end";
        };
        "[I" = {
          query = "@conditional.outer";
          desc = "Prev conditional end";
        };
        "[L" = {
          query = "@loop.outer";
          desc = "Prev loop end";
        };
      };
    };
  };

  hmts.enable = true;
}
