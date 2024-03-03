//+------------------------------------------------------------------+
//|                                                 kohonen maps.mqh |
//|                                    Copyright 2022, Fxalgebra.com |
//|                        https://www.mql5.com/en/users/omegajoctan |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Fxalgebra.com"
#property link      "https://www.mql5.com/en/users/omegajoctan"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include <MALE5\MatrixExtend.mqh>
#include <MALE5\Tensors.mqh>
#include <MALE5\preprocessing.mqh>
#include <MALE5\MqPlotLib\plots.mqh>

#define RANDOM_STATE 42

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

class CKohonenMaps
  {
   protected:
     CTensors *cluster_tensor;
     
     CPlots   plt;
     
      uint    n; //number of features
      uint    m; //number of clusters
      ulong   rows; 
      
      double  Euclidean_distance(const vector &v1, const vector &v2);
      string  CalcTimeElapsed(double seconds);
      
   private:
      matrix     Matrix;
      matrix     c_matrix; //Clusters
      matrix     w_matrix; //Weights matrix
      vector     w_vector; //weights vector
      matrix     o_matrix; //Output layer matrix
   
   public:
                  CKohonenMaps(matrix &matrix_, bool save_clusters=true, uint clusters=2, double alpha=0.01, uint epochs=100);
                 ~CKohonenMaps(void);
                 
                  uint predict(vector &v);
                  vector predict(matrix &matrix_);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CKohonenMaps::CKohonenMaps(matrix &matrix_, bool save_clusters=true, uint clusters=2, double alpha=0.01, uint epochs=100)
 {
   Matrix = matrix_;
   
   n = (uint)matrix_.Cols();
   rows = matrix_.Rows();
   m = clusters; 
   
   cluster_tensor = new CTensors(m);
   
   w_matrix =MatrixExtend::Random(0.0, 1.0, n, m, RANDOM_STATE); 
   
   #ifdef DEBUG_MODE
      Print("w Matrix\n",w_matrix,"\nMatrix\n",Matrix);
   #endif 
   
   vector D(m); //Euclidean distance btn clusters
   
   
   for (uint epoch=0; epoch<epochs; epoch++)
    {
    
      double epoch_start = GetMicrosecondCount()/(double)1e6, epoch_stop=0; 
      
      for (ulong i=0; i<rows; i++)
       {
         for (ulong j=0; j<m; j++)
           {
             D[j] = Euclidean_distance(Matrix.Row(i),w_matrix.Col(j));
           }
         
         #ifdef DEBUG_MODE  
            //Print("Euc distance ",D," Winning cluster ",D.ArgMin());
         #endif 
         
   //--- weights update
         
         ulong min = D.ArgMin();
         
         if (epoch == epochs-1) //last iteration
            cluster_tensor.Append(Matrix.Row(i), min); 

          
         vector w_new =  w_matrix.Col(min) + (alpha * (Matrix.Row(i) - w_matrix.Col(min)));
         
         w_matrix.Col(w_new, min);
       }
  
      epoch_stop =GetMicrosecondCount()/(double)1e6;    
      
      printf("Epoch [%d/%d] | %sElapsed ",epoch+1,epochs, CalcTimeElapsed(epoch_stop-epoch_start));
      
    }  //end of the training

//---

  #ifdef DEBUG_MODE
      Print("\nNew weights\n",w_matrix);
  #endif 

//---
   
   matrix mat= {};

   vector v;  
   matrix plotmatrix(rows, m); 
   
     for (uint i=0; i<this.cluster_tensor.SIZE; i++)
       {
          mat = this.cluster_tensor.Get(i);
          
          v  = MatrixExtend::MatrixToVector(mat);
          
          plotmatrix.Col(v, i);
       }   
    
    vector x(plotmatrix.Rows());    for (ulong i=0; i<x.Size(); i++) x[i] = (int)i+1;
    
    CColorGenerator clr;
    
    plt.Plot("kom", x, plotmatrix.Col(0), "map", "clusters","cluster"+string(1),CURVE_POINTS,clr.Next()); //plot the first cluster
    for (ulong i=1; i<plotmatrix.Cols(); i++) //start at the second column in the matrix | the second cluster
      {
        plt.AddPlot(plotmatrix.Col(i), "cluster"+string(i+1),clr.Next()); //Add the rest of clusters to the existing plot 
      }

//---

  
  if (save_clusters)
     for (uint i=0; i<this.cluster_tensor.SIZE; i++)
       {
         mat = this.cluster_tensor.Get(i);
         cluster_tensor.Add(mat, i);
         
         string header[]; ArrayResize(header, (int)mat.Cols());
         
         for (int k=0; k<ArraySize(header); k++) 
           header[k] = "col"+string(k);
         
         if (MatrixExtend::WriteCsv("SOM\\Cluster"+string(i+1)+".csv",mat,header))
            Print("Clusters CSV files saved under the directory Files\\SOM");
       }

//---

   Print("\nclusters");
   cluster_tensor.Print_();

 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CKohonenMaps::~CKohonenMaps(void)
 {
   ZeroMemory(Matrix);
   ZeroMemory(c_matrix); 
   ZeroMemory(w_matrix); 
   ZeroMemory(w_vector); 
   ZeroMemory(o_matrix); 
   delete (cluster_tensor);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

double CKohonenMaps:: Euclidean_distance(const vector &v1, const vector &v2)
  {
   double dist = 0;

   if(v1.Size() != v2.Size())
      Print(__FUNCTION__, " v1 and v2 not matching in size");
   else
     {
      double c = 0;
      for(ulong i=0; i<v1.Size(); i++)
         c += MathPow(v1[i] - v2[i], 2);

      dist = MathSqrt(c);
     }

   return(dist);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
uint CKohonenMaps::predict(vector &v)
 {
  vector temp_v = v;
  
  if (n != v.Size())
   {
     Print("Can't predict the cluster | the input vector size is not the same as the trained matrix cols");
     return(-1);
   }
   
   vector D(m); //Euclidean distance btn clusters
   
   for (ulong j=0; j<m; j++)
       D[j] = Euclidean_distance(v, w_matrix.Col(j));
   
   v.Copy(temp_v);
   return((uint)D.ArgMin());
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

vector CKohonenMaps::predict(matrix &matrix_)
 {   
   vector v(n);
   
   if (n != matrix_.Cols())
      {
         Print("Can't predict the cluster | the input matrix Cols is not the same size as the trained matrix cols");
         return (v);
      }
   
   for (ulong i=0; i<matrix_.Rows(); i++)
      v[i] = predict(matrix_.Row(i));
      
    return(v);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

string CKohonenMaps::CalcTimeElapsed(double seconds)
 {
  string time_str = "";
  
  uint minutes=0, hours=0;
  
   if (seconds >= 60)
     time_str = StringFormat("%d Minutes and %.3f Seconds ",minutes=(int)round(seconds/60.0), ((int)seconds % 60));     
   if (minutes >= 60)
     time_str = StringFormat("%d Hours %d Minutes and %.3f Seconds ",hours=(int)round(minutes/60.0), minutes, ((int)seconds % 60));
   else
     time_str = StringFormat("%.3f Seconds ",seconds);
     
   return time_str;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
