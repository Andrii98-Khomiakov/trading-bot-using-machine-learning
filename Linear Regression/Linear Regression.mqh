//+------------------------------------------------------------------+
//|                                            Linear Regression.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Fxalgebra.com"
#property link      "https://www.mql5.com/en/users/omegajoctan" 

//+------------------------------------------------------------------+

#include <MALE5\metrics.mqh>
#include <MALE5\matrix_utils.mqh>
#include <MALE5\preprocessing.mqh>

//+------------------------------------------------------------------+

class CLinearRegression
  {
   private:
   
   CMetrics metrics;
   CMatrixutils matrix_utils;
   CPreprocessing *normalize_x;
   CPreprocessing *normalize_y;
  
   protected:  
                        ulong  m_rows, m_cols;
                        uint   iterations;
                        bool   data_norm;
                        bool   training_grad; //currently Training by gradient descent
   
   private:
                        double dx_wrt_bo(matrix &x_matrix, vector &y_vector);
                        vector dx_wrt_b1(matrix &x_matrix, vector &y_vector);
    
   public:
                        matrix Betas;   //Coefficients matrix
                        vector Betas_v; //Coefficients vector
                        
                        CLinearRegression(matrix &x_matrix, vector &y_vector, norm_technique NORM_METHOD); //Least squares estimator
                        CLinearRegression(matrix<double> &x_matrix,vector &y_vector, norm_technique NORM_METHOD, double alpha, uint iters = 1000); //LR by Gradient descent
                        
                       ~CLinearRegression(void);
                        
                        double LRModelPred(vector &x); 
                        vector LRModelPred(matrix &x_matrix);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLinearRegression::CLinearRegression(matrix &x_matrix, vector &y_vector, norm_technique NORM_METHOD)
 {      
 
  matrix XMatrix =x_matrix; vector YVector = y_vector; 
 
  matrix YMatrix = {};
  YMatrix = matrix_utils.VectorToMatrix(YVector);
  
   if (NORM_METHOD != NORM_NONE)
     {
       data_norm = true;
       normalize_x = new CPreprocessing(XMatrix, NORM_METHOD); 
       
       #ifndef LOG_REG
         normalize_y = new CPreprocessing(YMatrix,NORM_METHOD);
       #endif 

        YVector = matrix_utils.MatrixToVector(YMatrix);
     }
    
    m_rows = YVector.Size(); 
    m_cols = XMatrix.Cols();
    
    if (m_rows != XMatrix.Rows())
      {
         Print("FATAL: Unbalanced rows in the independent vector and x matrix");
         return;
      }
      
//---

    matrix design = matrix_utils.DesignMatrix(XMatrix);
   
//--- XTX
    
    matrix XT = design.Transpose();
    
    matrix XTX = XT.MatMul(design);
    
    //if (IS_DEBUG_MODE) Print("XTX\n",XTX);
    
//--- Inverse XTX

    matrix InverseXTX = XTX.Inv();
    
    //if (IS_DEBUG_MODE) Print("INverse XTX\n",InverseXTX);

//--- Finding XTY
   
   matrix XTY = XT.MatMul(YMatrix);
   
   //if (IS_DEBUG_MODE) Print("XTY\n",XTY);

//--- Coefficients
   
   Betas = InverseXTX.MatMul(XTY);
   //pre_processing.ReverseMinMaxScaler(Betas);
   
   Betas_v = matrix_utils.MatrixToVector(Betas);
   
   #ifdef DEBUG_MODE 
        Print("Betas\n",Betas);
   #endif 
   
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLinearRegression::CLinearRegression(matrix<double> &x_matrix, vector &y_vector, norm_technique NORM_METHOD, double alpha,uint iters=1000)
 {     
   matrix XMatrix = x_matrix; vector YVector = y_vector;
   training_grad = true;
    
   matrix YMatrix;
   YMatrix = matrix_utils.VectorToMatrix(YVector);
   
   
   if (NORM_METHOD != NORM_NONE)
     {
       data_norm = true;
       normalize_x = new CPreprocessing(XMatrix, NORM_METHOD); 
       
       #ifndef LOG_REG
         normalize_y = new CPreprocessing(YMatrix,NORM_METHOD);
       #endif 
       
       YVector = matrix_utils.MatrixToVector(YMatrix);
     }
    
  
    m_rows = YVector.Size();
    m_cols = XMatrix.Cols();
    
    
    if (m_rows != XMatrix.Rows())
      {
         Print("FATAL: Unbalanced rows in the independent vector and x matrix");
         return;
      }
//---

    iterations = iters;
    
    Betas_v.Resize(m_cols+1);

//---
     #ifdef DEBUG_MODE  
        Print("\nTraining a Linear Regression Model with Gradient Descent\n");
     #endif 
//---
     
     for (ulong i=0; i<iterations; i++)
       {
       
         if (i==0) Betas_v.Fill(0);

//---

         double bo = dx_wrt_bo(XMatrix,YVector);
         
         Betas_v[0] = Betas_v[0] - (alpha * bo);
         //printf("----> dx_wrt_bo | Intercept = %.8f | Real Intercept = %.8f",bo,Betas_v[0]);
         
         vector dx = dx_wrt_b1(XMatrix,YVector); 

//---

          for (ulong j=0; j<dx.Size(); j++)
            {
               //Print("out at iterations Betas _v ",Betas_v);
                
                  Betas_v[j+1] = Betas_v[j+1] - (alpha * dx[j]);
                  
                  //printf("k %d | ----> dx_wrt_b%d | Slope = %.8f | Real Slope = %.8f",j,j,dx[j],Betas_v[j+1]); 
            }
         
//---

           #ifdef DEBUG_MODE  
               Betas = matrix_utils.VectorToMatrix(Betas_v);
               double acc =0;
               //Print("Betas ",Betas);
                
               vector pred = LRModelPred(XMatrix);
                matrix_utils.NormalizeVector(dx,5);
               
               Print("[ ",i+1," ] Accuracy = ",NormalizeDouble(metrics.r_squared(YVector,pred)*100,2),"% | COST ---> WRT Intercept | ",NormalizeDouble(bo,5)," | WRT Coeff ",dx);

           #endif  
           
       } 
//---
    Betas = matrix_utils.VectorToMatrix(Betas_v);
    training_grad = false;
//---

    #ifdef DEBUG_MODE 
        matrix_utils.NormalizeVector(Betas_v,5);
        Print("Coefficients ",Betas_v);
    #endif 
    
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLinearRegression::~CLinearRegression(void)
 {
   ZeroMemory(Betas);
   ZeroMemory(Betas_v);
   
   delete (normalize_x);
   delete (normalize_y);
   data_norm = false;
   training_grad  = false;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CLinearRegression::dx_wrt_bo(matrix &x_matrix, vector &y_vector)
 {    
   double mx=0, sum=0;
   for (ulong i=0; i<x_matrix.Rows(); i++)
      {          
          mx = LRModelPred(x_matrix.Row(i));
          
          sum += (y_vector[i] - mx);  
      }  
   
   return(-2*sum);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector CLinearRegression::dx_wrt_b1(matrix &x_matrix, vector &y_vector)
 { 
   vector dx_vector(Betas_v.Size()-1);
   //Print("dx_vector.Size() = ",dx_vector.Size());
   
    double mx=0, sum=0;
   
    for (ulong b=0; b<dx_vector.Size(); b++)  
     {
       ZeroMemory(sum);
       
       for (ulong i=0; i<x_matrix.Rows(); i++)
         {             
             //Print("<<<    >>> intercept = ",mx," Betas_v ",Betas_v,"\n");
             
            mx = LRModelPred(x_matrix.Row(i));            

//---

            sum += (y_vector[i] - mx) * x_matrix[i][b];  
            //PrintFormat("%d xMatrix %.5f",i,x_matrix[i][b]); 
          
            dx_vector[b] = -2*sum;  
        }
    }
      
    return dx_vector;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CLinearRegression::LRModelPred(vector &x)
 {
   
   if (data_norm && !training_grad) normalize_x.Normalization(x);
   
   double pred =0; 
   
   double intercept = Betas_v[0];
   
   if (Betas_v.Size() == 0)
      {
         Print(__FUNCTION__,"Err, No coefficients available for LR model\nTrain the model before attempting to use it");
         return(0);
      }
   
    else
      { 
        if (x.Size() != Betas_v.Size()-1)
          Print(__FUNCTION__,"Err, X vars not same size as their coefficients vector ");
        else
          {
            for (ulong i=1; i<Betas_v.Size(); i++) 
               pred += x[i-1] * Betas_v[i];  
               
            pred += intercept; 
          }
      }
    
    vector v = {pred};
    
    #ifndef LOG_REG 
      if (data_norm && !training_grad) normalize_y.ReverseNormalization(v);
    #endif 
    
    return v[0];
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector CLinearRegression::LRModelPred(matrix &x_matrix)
 {
   vector pred(x_matrix.Rows());
   
   vector x_vec;
   
    for (ulong i=0; i<x_matrix.Rows(); i++)
      {
         x_vec = x_matrix.Row(i);

         pred[i] = NormalizeDouble(LRModelPred(x_vec),5);
         //printf("Actual %.5f pred %.5f ",actual[i],pred[i]);
      }
   
   return pred;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
