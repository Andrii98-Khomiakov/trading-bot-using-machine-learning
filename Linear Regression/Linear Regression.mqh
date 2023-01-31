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

enum scaler
  {
    MIN_MAX_SCALER,
    MEAN_NORM_SCALER,
    STANDARDIZATION, 
  };

//+------------------------------------------------------------------+

class CLinearRegression
  {
   private:
   
   CMetrics metrics;
   CMatrixutils matrix_utils;
   CPreprocessing pre_processing;
  
   protected:  
                        ulong  m_rows, m_cols;
                        
                        double alpha;
                        uint   iterations;
   
   private:
                        double dx_wrt_bo(matrix &x_matrix, vector &y_vector);
                        vector dx_wrt_b1(matrix &x_matrix, vector &y_vector);
    
   public:
                        matrix Betas;   //Coefficients matrix
                        vector Betas_v; //Coefficients vector
                        
                        CLinearRegression(matrix &x_matrix, vector &y_vector); //Least squares estimator
                        CLinearRegression(matrix<double> &x_matrix,vector &y_vector, scaler NORM_ENUM, double Lr, uint iters = 1000); //Lr by Gradient descent
                        CLinearRegression(matrix &x_matrix,vector &y_vector, vector &coeff_vector);
                        
                       ~CLinearRegression(void);
                        
                        double LRModelPred(const vector &x); 
                        vector LRModelPred(matrix &x_matrix);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLinearRegression::CLinearRegression(matrix &x_matrix, vector &y_vector)
 {      
    m_rows = y_vector.Size(); 
    
    m_cols = x_matrix.Cols();
    
    matrix YMatrix =  matrix_utils.VectorToMatrix(y_vector);
    
//---

    matrix design = matrix_utils.DesignMatrix(x_matrix);
   
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
CLinearRegression::CLinearRegression(matrix<double> &x_matrix, vector &y_vector,scaler NORM_ENUM, double Lr,uint iters=1000)
 {     
    switch(NORM_ENUM)
      {
       case MIN_MAX_SCALER:
            pre_processing.MinMaxScaler(x_matrix);
            pre_processing.MinMaxScaler(y_vector);
         break;
       case MEAN_NORM_SCALER:
            pre_processing.MeanNormalization(x_matrix);
            pre_processing.MeanNormalization(y_vector);
          break;
       case STANDARDIZATION:
            pre_processing.Standardization(x_matrix);
            pre_processing.Standardization(y_vector);
          break;
      }    
    
    m_rows = y_vector.Size();
    m_cols = x_matrix.Cols();
  
    matrix YMatrix =  matrix_utils.VectorToMatrix(y_vector);
    
//---

    alpha = Lr;
    iterations = iters;
    
    //Betas.Resize(1,m_cols);
    
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

         double bo = dx_wrt_bo(x_matrix,y_vector);
         
         Betas_v[0] = Betas_v[0] - (alpha * bo);
         //printf("----> dx_wrt_bo | Intercept = %.8f | Real Intercept = %.8f",bo,Betas_v[0]);
         
         vector dx = dx_wrt_b1(x_matrix,y_vector); 

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
                
               vector pred = LRModelPred(x_matrix);
                   
               Print("[ ",i," ] Accuracy = ",NormalizeDouble(metrics.r_squared(y_vector,pred)*100,2),"% | COST ---> WRT Intercept | ",NormalizeDouble(bo,5)," | WRT Coeff ",dx);

           #endif  
           
       } 
//---
    Betas = matrix_utils.VectorToMatrix(Betas_v);
//---

    #ifdef DEBUG_MODE 
     Print("Coefficients ",Betas_v);
    #endif 
    
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLinearRegression::CLinearRegression(matrix &x_matrix, vector &y_vector, vector &coeff_vector)
 {
   
   Betas_v = coeff_vector;
   Betas = matrix_utils.VectorToMatrix(Betas_v);
   
   m_rows = x_matrix.Rows(); 
   m_cols = x_matrix.Cols();
    
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLinearRegression::~CLinearRegression(void)
 {
   ZeroMemory(Betas);
   ZeroMemory(Betas_v);
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
            //PrintFormat("%d xMatrix %.5f",i,XMatrix[i][b]); 
          
            dx_vector[b] = -2*sum;  
        }
    }
      
    return dx_vector;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CLinearRegression::LRModelPred(const vector &x)
 {
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
      
    return pred;
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
