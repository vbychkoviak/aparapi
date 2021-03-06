#AccessingMultiDimNDRangeProposal
*A proposal for accessing multi-dim ND range execution Updated Dec 14, 2011 by frost.g...@gmail.com*

We can discuss this proposal either here (in comments) or via the discussion list here.

Note this is nothing to do with accessing Java 2D arrays in Aparapi. This discussion is focused on the ability to expose the execution of kernels over 1, 2 or 3 dimensions. The memory in each case is a single contiguous region (like a single dimension primitive array).

At present an Aparapi kernel can only be executed using a single dimension. If we wish to represent execution over WIDTH x HEIGHT element grid we would execute over the range (WIDTH*HEIGHT) and manually divide/mod getGlobalID() by WIDTH to determine the x and y for each.

Similarly we would multiply y by WIDTH and add x (y*WIDTH+x) to convert an X,Y location to a linear global id

    final static int WIDTH=128;
    final static int HEIGHT=64;
    final int in[] = new int[WIDTH*HEIGHT];
    final int out[] = new int[WIDTH*HEIGHT];
    Kernel kernel = new Kernel(){
       public void run(){
          int x = getGlobaId()%WIDTH;
          int y = getGlobalID()/WIDTH;
          if (!(x==1 || x==(WIDTH-1) || y==1 || y==(HEIGHT-1)){
             int sum = 0;
             for (int dx =-1; dx<2; dx++){
               for (int dy =-1; dy<2; dy++){
                 sum+=in[(y+dy)*WIDTH+(x+dx)];
               }
             }
             out[y*WIDTH+x] = sum/9;
             // or out[getGlobalID()] = sum/9;
          }
       }

    };
    kernel.execute(WIDTH*HEIGHT);

OpenCL natively allows the user to execute over 1, 2 or 3 dimension grids via the clEnqueueNDRangeKernel() method.

We chose not to expose this in Aparapi but there have been requests for us to allow it.

There are a number of things to consider here:

1. Extending the syntax of kernel.execute() to allow multi dimensional grids.
1. Mapping Kernel methods to OpenCL's get_local_id(int dim), get_local_size(int dim), get_group_id(int_dim), etc. At present we map kernel.getGlobalId() to get_local_id(0).
1. Handling all of these when an application drops back to JTP mode.

##Extending Kernel.execute(int range)
Sadly we can't overload Kernel.execute(int range), Kernel.execute(int xrange, int yrange) and Kernel.execute(int xrange, int yrange, int zrange) because we already have kernel.execute(int, int) mapped for executing mutiple passes over the linear range.

Remember

    for (int pass=0; pass<20; pass++){
       kernel(1024);
    }
Is equivalent to

    kernel(1024, 20);
I think I would prefer

    Kernel.execute(int range)
    Kernel.execute(int range, int passes)
    Kernel.executeXY(int xrange, int yrange)
    Kernel.executeXY(int xrange, int yrange, int passes)
    Kernel.executeXYZ(int xrange, int yrange, int zrange)
    Kernel.executeXYZ(int xrange, int yrange, int zrange, int passes)
    Obviously in the above calls we are only supplying the global bounds for the grid. We could also provide mappings allowing local ranges. I think I would prefer

    Kernel.executeLocal(int range, int local)
    Kernel.executeLocal(int range, int local, int passes)
    Kernel.executeXYLocal(int xrange, int yrange, int xlocalrange, int ylocalrange)
    Kernel.executeXYLocal(int xrange, int yrange, int xlocalrange, int ylocalrange, int passes)
    Kernel.executeXYZLocal(int xrange, int yrange, int zrange, int xlocalrange, int ylocalrange, int zlocalrange)
    Kernel.executeXYZLocal(int xrange, int yrange, int zrange, int xlocalrange, int ylocalrange, int zlocalrange, int passes)
Another alternative may be to create Range classes

    class Range{
      int passes;
      int width;
      static Range create(int width);
      static Range create(int width, int passes);
    }

    class Range2D extends Range{
       int height;
       static Range create(int width, int height);
       static Range create(int width, int height, int passes);

    }

    class Range3D extends Range2D{
       int depth;
       static Range create(int width, int height);
       static Range create(int width, int height, int passes);
    }
With appropriate constructors (or factory methods) to allow

    Kernel.execute(Range range)

Then execute would be simply.

    Kernel.execute(Range.create(1,1))

We can also arrange for the group size to be placed in the base Range class.

    class Range{
      int groupSize;
      int passes;
      int width;
      static Range create(int width);
      static Range create(int width, int passes);
    }

##Mapping to OpenCL multi dim methods. i.e get_global_id(1), get_local_size(2) etc
We could just add getGlobalId(int dim), getLocalSize(int dim) etc to replicate OpenCL methods.

I would prefer to offer the following global mappings

|Kernel	| OpenCL|
|-----|------|
|getGlobalId()|	get_global_id(0)|
|getGlobalX()|	get_global_id(0)|
|getGlobalY()|	get_global_id(1)|
|getGlobalZ()|	get_global_id(2)|
|getGlobalSize()|	get_global_size(0)|
|getGlobalWidth()|	get_global_size(0)|
|getGlobalHeight()|	get_global_size(1)|
|getGlobalDepth()|	get_global_size(2)|

And the following local mappings

|Kernel|	OpenCL|
|-----|-------|
|getLocalId()|	get_local_id(0)|
|getLocalX()|	get_local_id(0)|
|getLocalY()|	get_local_id(1)|
|getLocalZ()|	get_local_id(2)|
|getLocalSize()|	get_local_size(0)|
|getLocalWidth()|	get_local_size(0)|
|getLocalHeight()|	get_local_size(1)|
|getLocalDepth()|	get_local_size(2)|

##An example

    final static int WIDTH=128;
    final static int HEIGHT=64;
    final int in[] = new int[WIDTH*HEIGHT];
    final int out[] = new int[WIDTH*HEIGHT];
    Kernel kernel = new Kernel(){
       public void run(){
          int x = getGlobalX();
          int y = getGlobalY();
          if (!(x==1 || x==(getGlobalWidth()-1) || y==1 || y==(getGlobalHeight()-1)){
             int sum = 0;
             for (int dx =-1; dx<2; dx++){
               for (int dy =-1; dy<2; dy++){
                 sum+=in[(y+dy)*getGlobalWidth()+(x+dx)];
               }
             }
             out[y*getGlobalWidth()+x] = sum/9;
             // or out[getGlobalID()] = sum/9;
          }
       }

    };
    kernel.executeXY(WIDTH, HEIGHT);

Or if we choose the Range class approach.

    final static int WIDTH=128;
    final static int HEIGHT=64;
    final int in[] = new int[WIDTH*HEIGHT];
    final int out[] = new int[WIDTH*HEIGHT];
    Kernel kernel = new Kernel(){
       public void run(){
          int x = getGlobalX();
          int y = getGlobalY();
          if (!(x==1 || x==(getGlobalWidth()-1) || y==1 || y==(getGlobalHeight()-1)){
             int sum = 0;
             for (int dx =-1; dx<2; dx++){
               for (int dy =-1; dy<2; dy++){
                 sum+=in[(y+dy)*getGlobalWidth()+(x+dx)];
               }
             }
             out[y*getGlobalWidth()+x] = sum/9;
             // or out[getGlobalID()] = sum/9;
          }
       }

    };
    kernel.execute(Range2D.create(WIDTH, HEIGHT));

##Handling this from JTP mode
Mapping to OpenCL for this is all fairly straightforward.

In Java JTP mode we will have to emulate this. For get_global_id(0..3) (getGlobalX(), getGlobalY() and getGlobalZ() using our proposed Aparapi Java mappings) we can of course easily offer reasonable implementations, this just requires the Java code to essentially nest 3 loops (or emulate) and set globalX, globalY, globalZ inside each nesting.

For get_local_size(0..3) (getLocalWidth(), getLocalHeight() and getLocalDepth() using our proposed Aparapi Java mappings) we will need to break the globalWidth/globalHeight and globalDepth into some arbitrary equal 'chunks' (note I am avoiding using the word groups here to avoid confusion with get_group_size(0..3)!

At present we always create a synthetic group in JTP mode which is the the # or cores. This will need to be changed. If the user requests a grid (64,64,8,8) (global width 64, global height 64, local width 8, local height 8) then we will have to create a JTP group of 64 (8x8) and just in case the kernel code contains a barrier, we will need to ensure we launch 64 threads for this group. From our experience it is best to launch one thread per core, so we may lose some JTP performance executing in this mode.