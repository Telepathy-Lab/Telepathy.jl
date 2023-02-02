function print_ansi_colors()
    for i in 1:16
        for j in 1:16
            num = (i-1)*16 + j - 1
            nums = lpad(string(num), 3, "0")
            nums = lpad(nums, 4, " ")
            nums = rpad(nums, 5, " ")
            printstyled("$nums", reverse=true, color=num)
        end
        println()
    end
end
