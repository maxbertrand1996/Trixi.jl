# Based on https://hal.archives-ouvertes.fr/hal-03017566v1/document

#######################################
### Bilinear B Spline interpolation ###
#######################################

# Bilinear B Spline structure
mutable struct BilinearBSpline{x_type, y_type, z_type, h_type, Q_type, IP_type}

  x::x_type
  y::y_type
  z::z_type
  h::h_type
  Q::Q_type
  IP::IP_type

  BilinearBSpline(x, y, z, h, Q, IP) = new{typeof(x), typeof(y), typeof(z),
  typeof(h), typeof(Q), typeof(IP)}(x, y, z, h, Q, IP)
end

# Fill structure
function bilinear_b_spline(x::Vector, y::Vector, z::Matrix; smoothing_factor = 0.0)

  x, y, z = sort_data(x,y,z)

  # Consider spline smoothing if required
  if smoothing_factor > 0.0
    z = calc_tps(smoothing_factor, x, y, z)
  end

  n = length(x)
  m = length(y)
  h = x[2] - x[1]
  
  P = vcat(reshape(z', (m*n,1)))
  IP = [-1 1;
         1 0];

  Q = reshape(P, (n, m)) 

  BilinearBSpline(x, y, z, h, Q, IP)  
end

# Read from file
function bilinear_b_spline(path::String; smoothing_factor = 0.0)
  file = open(path)
  lines = readlines(file)
  close(file)

  n = parse(Int64, lines[2])
  m = parse(Int64, lines[4])
  
  x     = [parse(Float64, val) for val in lines[6      :5+n    ]]
  y     = [parse(Float64, val) for val in lines[(7+n)  :(6+n+m)]]
  z_tmp = [parse(Float64, val) for val in lines[(8+n+m):end    ]]

  z = transpose(reshape(z_tmp, (n, m)))

  bilinear_b_spline(x, y, Matrix(z); smoothing_factor = smoothing_factor)
end

######################################
### Bicubic B Spline interpolation ###
######################################

# Bicubic B Spline structure
# The entries of z are set to be the x values horizontally
# and y values vertically
mutable struct BicubicBSpline{x_type, y_type, z_type, h_type, Q_type, IP_type}

  x::x_type
  y::y_type
  z::z_type
  h::h_type
  Q::Q_type
  IP::IP_type

  BicubicBSpline(x, y, z, h, Q, IP) = new{typeof(x), typeof(y), typeof(z), typeof(h), 
  typeof(Q), typeof(IP)}(x, y, z, h, Q, IP)
end

# Fill structure
function bicubic_b_spline(x::Vector, y::Vector, z::Matrix; boundary = "free", smoothing_factor = 0.0)

  x, y, z = sort_data(x,y,z)

  # Consider spline smoothing if required
  if smoothing_factor > 0.0
    z = calc_tps(smoothing_factor, x, y, z)
  end

  n = length(x)
  m = length(y)
  h = x[2] - x[1]
  boundary_elmts = 4 + 2*m + 2*n
  inner_elmts = m*n
  P = vcat(reshape(z', (inner_elmts,1)), zeros(boundary_elmts))
  
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
    for i in 1:inner_elmts
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
    for i in (inner_elmts+1):(inner_elmts+m)
      Phi[i, idx + (n+2) + 1] =  1
      Phi[i, idx + (n+2) + 2] = -2
      Phi[i, idx + (n+2) + 3] =  1
      idx += (n+2)
    end

    # right edge (v+)
    idx = 0
    for i in (inner_elmts+(m+1)):(inner_elmts+(2*m))
      Phi[i, idx + (n+2) + (n)  ] =  1
      Phi[i, idx + (n+2) + (n+1)] = -2
      Phi[i, idx + (n+2) + (n+2)] =  1
      idx += (n+2)
    end

    # upper edge (u-)
    idx = 0
    for i in (inner_elmts+(2*m)+1):(inner_elmts+(2*m)+n)
      Phi[i, idx           + 2] =  1
      Phi[i, idx +   (n+2) + 2] = -2
      Phi[i, idx + 2*(n+2) + 2] =  1
      idx += 1
    end

    # lower edge (u+)
    idx = (m-1) * (n+2)
    for i in (inner_elmts+(2*m)+(n+1)):(inner_elmts+(2*m)+(2*n))
      Phi[i, idx           + 2] =  1
      Phi[i, idx +   (n+2) + 2] = -2
      Phi[i, idx + 2*(n+2) + 2] =  1
      idx += 1
    end
    
    ## corners ##
    i = inner_elmts + boundary_elmts - 3   
    
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

    BicubicBSpline(x, y, z, h, Q, IP)

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
      for i in 1:inner_elmts
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
      for i in (inner_elmts+1):(inner_elmts+m)
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
      for i in (inner_elmts+(m+1)):(inner_elmts+(2*m))
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
      for i in (inner_elmts+(2*m)+1):(inner_elmts+(2*m)+n)
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
      for i in (inner_elmts+(2*m)+(n+1)):(inner_elmts+(2*m)+(2*n))
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
      i = inner_elmts + boundary_elmts - 3   
    
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

      BicubicBSpline(x, y, z, h, Q, IP)
    end
    
  else
    @error("Only free and not-a-knot boundary conditions are implemented!")
  
  end

end

# Read from file
function bicubic_b_spline(path::String; boundary = "free", smoothing_factor = 0.0)
  file = open(path)
  lines = readlines(file)
  close(file)

  n = parse(Int64, lines[2])
  m = parse(Int64, lines[4])
  
  x     = [parse(Float64, val) for val in lines[6      :5+n    ]]
  y     = [parse(Float64, val) for val in lines[(7+n)  :(6+n+m)]]
  z_tmp = [parse(Float64, val) for val in lines[(8+n+m):end    ]]

  z = transpose(reshape(z_tmp, (n, m)))

  bicubic_b_spline(x, y, Matrix(z); boundary = boundary, smoothing_factor = smoothing_factor)
end