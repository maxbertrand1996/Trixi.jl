######################################
### Bicubic B Spline interpolation ###
######################################

# Bicubic B Spline structure
mutable struct BicubicBSpline{x_type, y_type, z_type, hx_type, hy_type, Q_type, IP_type}

  x::x_type
  y::y_type
  z::z_type
  hx::hx_type
  hy::hy_type
  Q::Q_type
  IP::IP_type

  BicubicBSpline(x, y, z, hx, hy, Q, IP) = new{typeof(x), typeof(y), typeof(z), typeof(hx),
  typeof(hy), typeof(Q), typeof(IP)}(x, y, z, hx, hy, Q, IP)
end

# Fill structure
function bicubic_b_spline(x::Vector, y::Vector, z::Matrix; boundary = "free")

  x, y, z = sort_data(x,y,z)

  n = length(x)
  m = length(y)
  hx = x[2] - x[1]
  hy = y[2] - y[1]
  out_elmts = 4 + 2*m + 2*n
  int_elmts = m*n
  P = vcat(reshape(z', (int_elmts,1)), zeros(out_elmts))
  
  IP = [-1  3 -3 1;
         3 -6  3 0;
        -3  0  3 0;
         1  4  1 0]

  # Fill Phi for the different boundary conditions

  ########################
  ## Free end condition ##
  ########################
  if boundary == "free"
    Phi = spzeros((m+2)*(n+2), (m+2)*(n+2))

    # Fill inner point matrix
    idx = 0
    for i in 1:int_elmts
      Phi[i, idx           + 1] =  1
      Phi[i, idx           + 2] =  4
      Phi[i, idx           + 3] =  1
      Phi[i, idx +   (n+2) + 1] =  4
      Phi[i, idx +   (n+2) + 2] = 16
      Phi[i, idx +   (n+2) + 3] =  4
      Phi[i, idx + 2*(n+2) + 1] =  1
      Phi[i, idx + 2*(n+2) + 2] =  4
      Phi[i, idx + 2*(n+2) + 3] =  1

      if (i % n) == 0
        idx += 3
      else
        idx += 1
      end
    end

    # left edge (v-)
    idx = 0
    for i in (int_elmts+1):(int_elmts+m)
      Phi[i, idx + (n+2) + 1] =  1
      Phi[i, idx + (n+2) + 2] = -2
      Phi[i, idx + (n+2) + 3] =  1
      idx += (n+2)
    end

    # right edge (v+)
    idx = 0
    for i in (int_elmts+(m+1)):(int_elmts+(2*m))
      Phi[i, idx + (n+2) + (n)  ] =  1
      Phi[i, idx + (n+2) + (n+1)] = -2
      Phi[i, idx + (n+2) + (n+2)] =  1
      idx += (n+2)
    end

    # upper edge (u-)
    idx = 0
    for i in (int_elmts+(2*m)+1):(int_elmts+(2*m)+n)
      Phi[i, idx           + 2] =  1
      Phi[i, idx +   (n+2) + 2] = -2
      Phi[i, idx + 2*(n+2) + 2] =  1
      idx += 1
    end

    # lower edge (u+)
    idx = (m-1) * (n+2)
    for i in (int_elmts+(2*m)+(n+1)):(int_elmts+(2*m)+(2*n))
      Phi[i, idx           + 2] =  1
      Phi[i, idx +   (n+2) + 2] = -2
      Phi[i, idx + 2*(n+2) + 2] =  1
      idx += 1
    end
    
    ## corners ##
    i = int_elmts + out_elmts - 3   
    
    # upper left corner
    Phi[(i  ),               1] =  1 
    Phi[(i  ),       (n+2) + 2] = -2
    Phi[(i  ), (  2)*(n+2) + 3] =  1
    # upper right corner
    Phi[(i+1),       (n+2)    ] =  1
    Phi[(i+1), (  2)*(n+2) - 1] = -2
    Phi[(i+1), (  3)*(n+2) - 2] =  1
    # lower left corner
    Phi[(i+2), (m-1)*(n+2) + 3] =  1
    Phi[(i+2), (m  )*(n+2) + 2] = -2
    Phi[(i+2), (m+1)*(n+2) + 1] =  1
    # lower right corner
    Phi[(i+3), (m  )*(n+2) - 2] =  1
    Phi[(i+3), (m+1)*(n+2) - 1] = -2
    Phi[(i+3), (m+2)*(n+2)    ] =  1

    Q_temp = 36 * (Phi\P)
    Q      = reshape(Q_temp, (n+2, m+2)) 

    BicubicBSpline(x, y, z, hx, hy, Q, IP)

  ###################################
  ## not-a-knot boundary condition ##
  ###################################
  elseif boundary == "not-a-knot"
    if (n < 4) || (m < 4)
      @error("To consider the not-a-knot condition, the dimensions of z must be greater than 4!")
    
    else
      Phi = spzeros((m+2)*(n+2), (m+2)*(n+2))

      # Fill inner point matrix
      idx = 0
      for i in 1:int_elmts
        Phi[i, idx           + 1] =  1
        Phi[i, idx           + 2] =  4
        Phi[i, idx           + 3] =  1
        Phi[i, idx +   (n+2) + 1] =  4
        Phi[i, idx +   (n+2) + 2] = 16
        Phi[i, idx +   (n+2) + 3] =  4
        Phi[i, idx + 2*(n+2) + 1] =  1
        Phi[i, idx + 2*(n+2) + 2] =  4
        Phi[i, idx + 2*(n+2) + 3] =  1

        if (i % n) == 0
          idx += 3
        else
          idx += 1
        end
      end

      # left edge (v-)
      idx = 0
      for i in (int_elmts+1):(int_elmts+m)
        Phi[i, idx           + 1] = - 1
        Phi[i, idx           + 2] =   4
        Phi[i, idx           + 3] = - 6
        Phi[i, idx           + 4] =   4
        Phi[i, idx           + 5] = - 1
        Phi[i, idx +   (n+2) + 1] = - 4
        Phi[i, idx +   (n+2) + 2] =  16
        Phi[i, idx +   (n+2) + 3] = -24
        Phi[i, idx +   (n+2) + 4] =  16
        Phi[i, idx +   (n+2) + 5] = - 4
        Phi[i, idx + 2*(n+2) + 1] = - 1
        Phi[i, idx + 2*(n+2) + 2] =   4
        Phi[i, idx + 2*(n+2) + 3] = - 6
        Phi[i, idx + 2*(n+2) + 4] =   4
        Phi[i, idx + 2*(n+2) + 5] = - 1
        idx += (n+2)
      end

      # right edge (v+)
      idx = (n+2) + 1
      for i in (int_elmts+(m+1)):(int_elmts+(2*m))
        Phi[i, idx           - 5] = - 1
        Phi[i, idx           - 4] =   4
        Phi[i, idx           - 3] = - 6
        Phi[i, idx           - 2] =   4
        Phi[i, idx           - 1] = - 1
        Phi[i, idx +   (n+2) - 5] = - 4
        Phi[i, idx +   (n+2) - 4] =  16
        Phi[i, idx +   (n+2) - 3] = -24
        Phi[i, idx +   (n+2) - 2] =  16
        Phi[i, idx +   (n+2) - 1] = - 4
        Phi[i, idx + 2*(n+2) - 5] = - 1
        Phi[i, idx + 2*(n+2) - 4] =   4
        Phi[i, idx + 2*(n+2) - 3] = - 6
        Phi[i, idx + 2*(n+2) - 2] =   4
        Phi[i, idx + 2*(n+2) - 1] = - 1
        idx += (n+2)
      end

      # upper edge (u-)
      idx = 0
      for i in (int_elmts+(2*m)+1):(int_elmts+(2*m)+n)
        Phi[i, idx           + 1] = - 1
        Phi[i, idx           + 2] = - 4
        Phi[i, idx           + 3] = - 1
        Phi[i, idx +   (n+2) + 1] =   4
        Phi[i, idx +   (n+2) + 2] =  16
        Phi[i, idx +   (n+2) + 3] =   4
        Phi[i, idx + 2*(n+2) + 1] = - 6
        Phi[i, idx + 2*(n+2) + 2] = -24
        Phi[i, idx + 2*(n+2) + 3] = - 6
        Phi[i, idx + 3*(n+2) + 1] =   4
        Phi[i, idx + 3*(n+2) + 2] =  16
        Phi[i, idx + 3*(n+2) + 3] =   4
        Phi[i, idx + 4*(n+2) + 1] = - 1
        Phi[i, idx + 4*(n+2) + 2] = - 4
        Phi[i, idx + 4*(n+2) + 3] = - 1
        idx += 1
      end

      # lower edge (u+)
      idx = (m-3) * (n+2)
      for i in (int_elmts+(2*m)+(n+1)):(int_elmts+(2*m)+(2*n))
        Phi[i, idx           + 1] = - 1
        Phi[i, idx           + 2] = - 4
        Phi[i, idx           + 3] = - 1
        Phi[i, idx +   (n+2) + 1] =   4
        Phi[i, idx +   (n+2) + 2] =  16
        Phi[i, idx +   (n+2) + 3] =   4
        Phi[i, idx + 2*(n+2) + 1] = - 6
        Phi[i, idx + 2*(n+2) + 2] = -24
        Phi[i, idx + 2*(n+2) + 3] = - 6
        Phi[i, idx + 3*(n+2) + 1] =   4
        Phi[i, idx + 3*(n+2) + 2] =  16
        Phi[i, idx + 3*(n+2) + 3] =   4
        Phi[i, idx + 4*(n+2) + 1] = - 1
        Phi[i, idx + 4*(n+2) + 2] = - 4
        Phi[i, idx + 4*(n+2) + 3] = - 1
        idx += 1
      end

      ## corners ##
      i = int_elmts + out_elmts - 3   
    
      # upper left corner
      Phi[(i  ),               1] =  1
      Phi[(i  ),               2] = -1
      Phi[(i  ),       (n+2) + 1] = -1
      Phi[(i  ),       (n+2) + 2] =  1
      # upper right corner
      Phi[(i+1),       (n+2) - 1] = -1
      Phi[(i+1),       (n+2)    ] =  1
      Phi[(i+1),     2*(n+2) - 1] =  1
      Phi[(i+1),     2*(n+2)    ] = -1
      # lower left corner
      Phi[(i+2), (m  )*(n+2) + 1] = -1
      Phi[(i+2), (m  )*(n+2) + 2] =  1
      Phi[(i+2), (m+1)*(n+2) + 1] =  1
      Phi[(i+2), (m+1)*(n+2) + 2] = -1
      # lower right corner
      Phi[(i+3), (m+1)*(n+2) - 1] =  1
      Phi[(i+3), (m+1)*(n+2)    ] = -1
      Phi[(i+3), (m+2)*(n+2) - 1] = -1
      Phi[(i+3), (m+2)*(n+2)    ] =  1

      Q_temp = 36 * (Phi\P)
      Q      = reshape(Q_temp, (n+2, m+2)) 

      BicubicBSpline(x, y, z, hx, hy, Q, IP)
    end

  ###############################
  ## smooth boundary condition ##
  ###############################
  elseif boundary == "smooth"
    
    Q = zeros(m+2, n+2)

    # inner points
    Q[2:(m+1), 2:(n+1)] = reshape(P[1:int_elmts], (n, m)) 

    # upper edge
    Q[1, 2:(n+1)] = deepcopy(Q[2, 2:(n+1)])
    # lower edge
    Q[end, 2:(n+1)] = deepcopy(Q[end-1, 2:(n+1)])
    # left edge
    Q[2:(m+1), 1] = deepcopy(Q[2:(m+1), 2])
    # right edge
    Q[2:(m+1), end] = deepcopy(Q[2:(m+1), end-1])

    # top left corner
    Q[1, 1] = deepcopy(Q[2, 2])
    # top right corner
    Q[1, end] = deepcopy(Q[2, end-1])
    # bottom left corner
    Q[end, 1] = deepcopy(Q[end-1, 2])
    # bottom right corner
    Q[end, end] = deepcopy(Q[end-1, end-1])
    
    BicubicBSpline(x, y, z, hx, hy, Q, IP)
    
  else
    @error("Only free, not-a-knot and smooth boundary conditions are implemented!")
  
  end

end

# Read from file
function bicubic_b_spline(path::String; boundary = "free")
  file = open(path)
  lines = readlines(file)
  close(file)

  num_elements_x = parse(Int64, lines[2])
  num_elements_y = parse(Int64, lines[4])
  
  x  = [parse(Float64, val) for val in lines[6:5+num_elements_x]]
  y  = [parse(Float64, val) for val in lines[(7+num_elements_x):(6+num_elements_x+num_elements_y)]]
  z_tmp = [parse(Float64, val) for val in lines[(8+num_elements_x+num_elements_y):end]]

  z = transpose(reshape(z_tmp, (num_elements_x, num_elements_y)))

  bicubic_b_spline(x, y, Matrix(z); boundary = boundary)
end